//
//  TelescopiumTracerTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

import Dispatch
import Foundation
import Testing
@testable import Telescopium

struct TelescopiumTracerTests {
    private struct DescribedError: LocalizedError {
        let describe: @Sendable () -> String
        var errorDescription: String? { describe() }
    }

    private struct BlockingExporter: SpanExporter {
        let entered = DispatchSemaphore(value: 0)
        let secondEndReturned = DispatchSemaphore(value: 0)

        func export(_ record: SpanRecord) {
            entered.signal()
            #expect(secondEndReturned.wait(timeout: .now() + 5) == .success)
        }
    }

    @Test("Concurrent end calls deliver exactly one completed record")
    func concurrentEnd() throws {
        let exporter = CapturingSpanExporter()
        let tracer = TelescopiumTracer(exporter: exporter)
        let span = tracer.startSpan("Request", ofKind: .client, parent: nil)
        let response = SpanEvent("Response received")
        span.setMetadata(200, forKey: "status")
        span.addEvent(response)

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            tracer.endSpan(span, throwing: nil)
        }
        span.setMetadata(500, forKey: "status")
        span.addEvent(SpanEvent("Late event"))
        tracer.endSpan(span, throwing: nil)

        let records = exporter.records
        try #require(records.count == 1)
        let record = records[0]
        #expect(record.context == span.context)
        #expect(record.name == "Request")
        #expect(record.kind == .client)
        #expect(record.parentSpanId == nil)
        #expect(record.duration >= .zero)
        #expect(record.metadata == ["status": 200])
        #expect(record.events == [response])
        #expect(record.error == nil)
    }

    @Test("Concurrent ends without an exporter close the span without describing its error")
    func concurrentEndWithoutExporter() {
        let tracer = TelescopiumTracer()
        let span = tracer.startSpan("Request", ofKind: .client, parent: nil)
        let error = DescribedError {
            Issue.record("A tracer without an exporter evaluated errorDescription")
            return "Offline"
        }

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            tracer.endSpan(span, throwing: error)
        }

        #expect(span.finish(throwing: nil) == nil)
    }

    @Test("Wall-clock adjustments in either direction leave the elapsed duration intact", arguments: [Date.distantFuture, .distantPast])
    func elapsedDuration(startTime: Date) throws {
        let now = ContinuousClock.now
        let startInstant = now.advanced(by: .seconds(-3))
        let span = TelescopiumSpan(
            name: "Request",
            kind: .client,
            parent: nil,
            startTime: startTime,
            startInstant: startInstant,
        )
        let record = try #require(span.finish(throwing: nil))

        #expect(record.startTime == startTime)
        #expect(record.endTime > Date.distantPast && record.endTime < Date.distantFuture)
        #expect(record.duration >= .seconds(3))
        #expect(record.duration <= startInstant.duration(to: .now))
    }

    @Test("A second end returns while the exporter is running")
    func exporterRunsOutsideSpanLock() throws {
        let exporter = BlockingExporter()
        let firstEndReturned = DispatchSemaphore(value: 0)
        let tracer = TelescopiumTracer(exporter: exporter)
        let span = tracer.startSpan("Request", ofKind: .client, parent: nil)
        DispatchQueue.global().async {
            tracer.endSpan(span, throwing: nil)
            firstEndReturned.signal()
        }
        try #require(exporter.entered.wait(timeout: .now() + 5) == .success)
        tracer.endSpan(span, throwing: nil)
        exporter.secondEndReturned.signal()
        #expect(firstEndReturned.wait(timeout: .now() + 5) == .success)
    }

    @Test("Only the first end describes its error, after freezing and unlocking the span")
    func errorConversionRunsOutsideSpanLock() throws {
        let exporter = CapturingSpanExporter()
        let tracer = TelescopiumTracer(exporter: exporter)
        let span = tracer.startSpan("Request", ofKind: .client, parent: nil)
        let describing = DispatchSemaphore(value: 0)
        let repeatedEndReturned = DispatchSemaphore(value: 0)
        let delivered = DispatchSemaphore(value: 0)
        let firstError = DescribedError {
            describing.signal()
            #expect(repeatedEndReturned.wait(timeout: .now() + 5) == .success)
            return "Offline"
        }
        DispatchQueue.global().async {
            tracer.endSpan(span, throwing: firstError)
            delivered.signal()
        }

        try #require(describing.wait(timeout: .now() + 5) == .success)
        span.addEvent(SpanEvent("Late event"))
        let lateError = DescribedError {
            Issue.record("A repeated end evaluated its error")
            return "Late failure"
        }
        tracer.endSpan(span, throwing: lateError)
        repeatedEndReturned.signal()

        try #require(delivered.wait(timeout: .now() + 5) == .success)
        let records = exporter.records
        try #require(records.count == 1)
        #expect(records[0].error?.message == "Offline")
        #expect(records[0].events.isEmpty)
    }
}
