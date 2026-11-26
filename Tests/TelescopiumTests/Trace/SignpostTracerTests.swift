//
//  SignpostTracerTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

import Dispatch
import os
import Testing
@testable import Telescopium

struct SignpostTracerTests {
    private enum RequestError: Error { case cancelled }

    private struct CountingTracer: Tracer {
        let endCalls = LockedValue(0)
        let base = TelescopiumTracer()

        func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> TelescopiumSpan {
            base.startSpan(name, ofKind: kind, parent: parent)
        }

        func endSpan(_ span: TelescopiumSpan, throwing error: (any Error)?) {
            endCalls.withLock { $0 += 1 }
            base.endSpan(span, throwing: error)
        }
    }

    @Test(arguments: [OSSignposter.disabled, OSSignposter(subsystem: "TelescopiumTests", category: .pointsOfInterest)])
    func concurrentEndForwardsOnce(signposter: OSSignposter) {
        let base = CountingTracer()
        let tracer = base.signposted(by: signposter)
        let span = tracer.startSpan("Request", ofKind: .client, parent: nil)

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            tracer.endSpan(span, throwing: nil)
        }

        #expect(base.endCalls.withLock { $0 } == 1)
    }

    @Test(arguments: [OSSignposter.disabled, OSSignposter(subsystem: "TelescopiumTests", category: .pointsOfInterest)])
    func overlappingSpansForwardToTheirOriginalRecords(signposter: OSSignposter) throws {
        let exporter = CapturingSpanExporter()
        let base = TelescopiumTracer(exporter: exporter)
        let tracer = base.signposted(by: signposter)
        let parent = SpanContext.root()
        let first = tracer.startSpan("Request", ofKind: .client, parent: parent)
        let second = tracer.startSpan("Request", ofKind: .client, parent: parent)
        let retry = SpanEvent("Retry", metadata: ["attempt": 1])
        first.addEvent(retry)
        first.setMetadata(1, forKey: "attempt")
        tracer.endSpan(second, throwing: RequestError.cancelled)
        tracer.endSpan(first, throwing: nil)

        let records = exporter.records
        try #require(records.count == 2)
        #expect(records.map(\.context) == [second.context, first.context])
        #expect(first.context != second.context)
        #expect(records.allSatisfy { $0.parentSpanId == parent.traceParent.spanId && $0.kind == .client })
        #expect(records[0].error == ErrorInfo(RequestError.cancelled))
        #expect(records[0].metadata.isEmpty)
        #expect(records[0].events.isEmpty)
        #expect(records[1].error == nil)
        #expect(records[1].metadata == ["attempt": 1])
        #expect(records[1].events == [retry])
    }
}
