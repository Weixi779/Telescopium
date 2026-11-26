//
//  TracePublicAPITests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Telescopium
import Testing

struct TracePublicAPITests {
    @Test("An injected tracer supports sync and async scopes with the caller's defaults")
    @MainActor
    func scopedOperations() async {
        final class Draft {}
        let draft = Draft()
        let exporter = CapturingSpanExporter()
        let tracer: any Tracer = TelescopiumTracer(exporter: exporter)

        let result = await tracer.withSpan("Edit") { outer in
            await Task.yield()
            MainActor.assertIsolated()
            tracer.withSpan("Read") { inner in
                #expect(inner.context.traceParent.traceId == outer.context.traceParent.traceId)
            }
            #expect(TraceScope.current == outer.context)
            return draft
        }

        #expect(result === draft)
        let records = exporter.records
        #expect(records.map(\.name) == ["Read", "Edit"])
        #expect(records.map(\.kind) == [.internal, .internal])
    }

    @Test("An exporter fixture can construct a root record with independent wall and elapsed times")
    func constructRecord() throws {
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 99)
        let context = SpanContext.root()
        let record = SpanRecord(
            name: "Request",
            kind: .client,
            context: context,
            startTime: start,
            endTime: end,
            duration: .milliseconds(10),
        )

        #expect(record.context == context)
        #expect(record.startTime == start && record.endTime == end)
        #expect(record.duration == .milliseconds(10))
        #expect(record.parentSpanId == nil && record.error == nil)
        #expect(record.metadata.isEmpty && record.events.isEmpty)

        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(SpanRecord.self, from: data) == record)
    }

    @Test("A completed request round-trips with its parent, ordered events, metadata, and error")
    func completedRequestRoundTrip() throws {
        let parent = SpanContext.root()
        let start = Date(timeIntervalSince1970: 100)
        let end = start.addingTimeInterval(1)
        let record = SpanRecord(
            name: "GET /orders",
            kind: .client,
            context: parent.child(),
            parentSpanId: parent.traceParent.spanId,
            startTime: start,
            endTime: end,
            duration: .nanoseconds(900_000_123),
            metadata: ["request": ["attempts": [1, 2], "cached": false]],
            events: [
                SpanEvent("Attempt", timestamp: start, metadata: ["number": 1]),
                SpanEvent("Attempt", timestamp: end, metadata: ["number": 2]),
            ],
            error: ErrorInfo(typeName: "RequestError", message: "Timed out", domain: "Network", code: 42),
        )

        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(SpanRecord.self, from: data) == record)
    }
}
