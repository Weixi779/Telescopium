//
//  WithSpanTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
@testable import Telescopium

private enum DraftError: Error { case invalid }

private struct ScopeProbeExporter: LogExporter {
    let observations = LockedValue<[(record: LogRecord, parent: TraceParent?)]>([])

    func export(_ record: LogRecord) {
        let parent = TraceScope.current?.traceParent
        observations.withLock { $0.append((record, parent)) }
    }
}

private struct TestSpan: Span {
    let name: String
    let kind: SpanKind
    let parent: SpanContext?
    let context = SpanContext.root()

    func setMetadata(_ value: MetadataValue, forKey key: String) {}

    func addEvent(_ event: SpanEvent) {}
}

private struct TestTracer: Tracer {
    let ended = LockedValue<[(span: TestSpan, error: (any Error)?)]>([])

    func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> TestSpan {
        TestSpan(name: name, kind: kind, parent: parent)
    }

    func endSpan(_ span: TestSpan, throwing error: (any Error)?) {
        ended.withLock { $0.append((span, error)) }
    }
}

@Suite(.serialized)
struct WithSpanTests {
    private let exporter = CapturingSpanExporter()

    private var tracer: TelescopiumTracer {
        TelescopiumTracer(exporter: exporter)
    }

    @Test("Rebinding a page span parents the request and leaves the page open for later callbacks")
    func pageRequest() throws {
        let previous = Trace.currentTracer
        defer { Trace.register(tracer: previous) }
        Trace.register(tracer: tracer)

        let pageExporter = CapturingSpanExporter()
        let pageTracer = TelescopiumTracer(exporter: pageExporter)
        let page = pageTracer.startSpan("Order details", ofKind: .internal, parent: nil)
        let request = page.withCurrent {
            withSpan("GET /orders/{id}", ofKind: .client) { $0.context }
        }
        #expect(TraceScope.current == nil)
        let records = exporter.records
        try #require(records.count == 1)
        #expect(records[0].context == request)
        #expect(records[0].parentSpanId == page.context.traceParent.spanId)
        #expect(request.traceParent.traceId == page.context.traceParent.traceId)
        #expect(pageExporter.records.isEmpty)

        page.withCurrent { page.setMetadata(true, forKey: "refreshed") }
        pageTracer.endSpan(page, throwing: nil)
        #expect(pageExporter.records.map(\.context) == [page.context])
        #expect(pageExporter.records.first?.metadata["refreshed"] == true)
    }

    @Test("An async callback keeps its page context across suspension and restores the outer span on throw")
    @MainActor
    func rebindAcrossSuspension() async throws {
        let pageTracer = tracer
        let page = pageTracer.startSpan("Order details", ofKind: .internal, parent: nil)
        defer { pageTracer.endSpan(page, throwing: nil) }
        let existing: any Span = page
        try await withSpan("Refresh action") { outer in
            do {
                try await existing.withCurrent {
                    await Task.yield()
                    MainActor.assertIsolated()
                    #expect(TraceScope.current == page.context)
                    throw DraftError.invalid
                }
                Issue.record("Expected refresh to throw")
            } catch DraftError.invalid {
                #expect(TraceScope.current == outer.context)
                #expect(exporter.records.isEmpty)
            }
        }
        #expect(TraceScope.current == nil)
    }

    @Test("A failed request exports its complete record once through the registered tracer")
    func exportFailedRequest() throws {
        let previous = Trace.currentTracer
        defer { Trace.register(tracer: previous) }
        let requestTracer = tracer
        Trace.register(tracer: requestTracer)

        let parent = SpanContext.root()
        let timeout = URLError(.timedOut)
        let sent = SpanEvent("Request sent", metadata: ["attempt": 1])
        var request: TelescopiumSpan?
        let started = ContinuousClock.now
        TraceScope.$current.withValue(parent) {
            #expect(throws: timeout) {
                try withSpan("POST /orders", ofKind: .client) { span in
                    request = span as? TelescopiumSpan
                    span.setMetadata("checkout", forKey: "feature")
                    span.addEvent(sent)
                    throw timeout
                }
            }
        }
        let elapsed = started.duration(to: .now)
        let span = try #require(request)
        #expect(exporter.records.count == 1)
        requestTracer.endSpan(span, throwing: nil)

        let records = exporter.records
        try #require(records.count == 1)
        let record = records[0]
        #expect(record.name == "POST /orders")
        #expect(record.kind == .client)
        #expect(record.context == span.context)
        #expect(record.context.traceParent.traceId == parent.traceParent.traceId)
        #expect(record.parentSpanId == parent.traceParent.spanId)
        #expect(record.duration >= .zero && record.duration <= elapsed)
        #expect(record.metadata == ["feature": "checkout"])
        #expect(record.events == [sent])
        #expect(record.error == ErrorInfo(timeout))
    }

    @Test("Repeated events keep their timestamps and metadata in recording order until the span ends")
    func eventsDuringSpan() throws {
        let first = SpanEvent("Retry", timestamp: Date(timeIntervalSince1970: 20), metadata: ["attempt": 1])
        let second = SpanEvent("Retry", timestamp: Date(timeIntervalSince1970: 10), metadata: ["attempt": 2])
        let span = tracer.withSpan("Request", ofKind: .internal) { span in
            span.addEvent(first)
            span.addEvent(second)
            return span
        }

        span.addEvent(SpanEvent("Late"))
        let record = try #require(exporter.records.first)
        #expect(record.events == [first, second])
        #expect(record.metadata.isEmpty)
    }

    @Test("A synchronous exporter sees the current span at each log call and loses it on later replay")
    func exporterScopeAtLogCall() {
        let probe = ScopeProbeExporter()
        let logger = Logger(recorder: LogRecorder(exporters: [probe]))

        let (a, b, c) = withSpan("A") { a in
            logger.info("A before")
            let b = withSpan("B") { b in
                logger.info("B")
                return b.context.traceParent
            }
            let c = withSpan("C") { c in
                logger.info("C")
                return c.context.traceParent
            }
            logger.info("A after")
            return (a.context.traceParent, b, c)
        }

        let observations = probe.observations.withLock { $0 }
        #expect(observations.map { $0.record.message } == ["A before", "B", "C", "A after"])
        #expect(observations.map(\.parent) == [a, b, c, a])
        #expect(Set([a.traceId, b.traceId, c.traceId]).count == 1)
        #expect(Set([a.spanId, b.spanId, c.spanId]).count == 3)

        let replay = ScopeProbeExporter()
        for observation in observations {
            replay.export(observation.record)
        }
        #expect(replay.observations.withLock { $0.map(\.parent) } == [nil, nil, nil, nil])
    }

    @Test("Replacing the app tracer inside a span affects new spans and preserves ownership of active spans")
    func replacingTracer() async throws {
        let previous = Trace.currentTracer
        defer { Trace.register(tracer: previous) }

        let first = TestTracer()
        let second = TestTracer()
        Trace.register(tracer: first)
        var outerContext: SpanContext?
        var innerContext: SpanContext?

        do {
            try await withSpan("Save") { outer in
                outerContext = outer.context
                Trace.register(tracer: second)
                await Task.yield()
                #expect(TraceScope.current == outer.context)

                innerContext = withSpan("Write", ofKind: .client) { inner in
                    #expect(TraceScope.current == inner.context)
                    return inner.context
                }
                #expect(TraceScope.current == outer.context)
                throw DraftError.invalid
            }
            Issue.record("Expected Save to throw")
        } catch DraftError.invalid {}

        let firstEnds = first.ended.withLock { $0 }
        let secondEnds = second.ended.withLock { $0 }
        try #require(firstEnds.count == 1 && secondEnds.count == 1)
        #expect(firstEnds[0].span.name == "Save")
        #expect(firstEnds[0].span.context == outerContext)
        #expect(firstEnds[0].span.parent == nil)
        #expect(firstEnds[0].error as? DraftError == .invalid)
        #expect(secondEnds[0].span.name == "Write")
        #expect(secondEnds[0].span.kind == .client)
        #expect(secondEnds[0].span.parent == outerContext)
        #expect(secondEnds[0].span.context == innerContext)
        #expect(secondEnds[0].error == nil)
        #expect(TraceScope.current == nil)
    }

    @Test("Synchronous children share a trace and restore the parent between siblings")
    func synchronousNesting() throws {
        let root = tracer.withSpan("Save draft", ofKind: .internal) { span in
            #expect(TraceScope.current == span.context)
            let first = tracer.withSpan("Prepare", ofKind: .internal) { $0.context }
            #expect(TraceScope.current == span.context)
            let second = tracer.withSpan("Write", ofKind: .internal) { $0.context }
            #expect(first.traceParent.spanId != second.traceParent.spanId)
            #expect(exporter.records.map(\.context) == [first, second])
            span.setMetadata(3, forKey: "bytes")
            return span
        }
        #expect(TraceScope.current == nil)
        root.setMetadata(9, forKey: "bytes")
        let records = exporter.records
        #expect(records.map(\.name) == ["Prepare", "Write", "Save draft"])
        let parent = try #require(records.last)
        #expect(parent.parentSpanId == nil)
        #expect(parent.context == root.context)
        #expect(parent.metadata["bytes"] == 3)
        for child in records.dropLast() {
            #expect(child.parentSpanId == root.context.traceParent.spanId)
            #expect(child.context.traceParent.traceId == root.context.traceParent.traceId)
        }
    }

    @Test("A sync failure freezes the record and restores the previous context")
    func syncThrow() throws {
        #expect(throws: DraftError.invalid) {
            try tracer.withSpan("Validate", ofKind: .internal) { _ in
                throw DraftError.invalid
            }
        }
        let record = try #require(exporter.records.first)
        #expect(record.error == ErrorInfo(DraftError.invalid))
        #expect(TraceScope.current == nil)
    }

    @Test("A locally created child inherits flags and vendor state from a bound remote context")
    func boundParent() throws {
        let header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        let parent = try #require(TraceParent(headerValue: header))
        let state = try #require(TraceState(headerValue: "acme=sample"))
        let remote = SpanContext(traceParent: parent, traceState: state, isRemote: true)
        TraceScope.$current.withValue(remote) {
            tracer.withSpan("Import", ofKind: .consumer) { _ in }
            #expect(TraceScope.current == remote)
        }
        let child = try #require(exporter.records.first)
        #expect(child.name == "Import")
        #expect(child.kind == .consumer)
        #expect(child.parentSpanId == parent.spanId)
        #expect(child.context.traceParent.traceId == parent.traceId)
        #expect(child.context.traceParent.flags == parent.flags)
        #expect(child.context.traceState == state)
        #expect(!child.context.isRemote)
    }

    @Test("Sibling tasks keep their own current span across suspension")
    func concurrentChildren() async {
        await withSpan("Import") { root in
            await withTaskGroup(of: SpanContext.self) { group in
                for name in ["First", "Second"] {
                    group.addTask {
                        #expect(TraceScope.current == root.context)
                        let child = await withSpan(name) { span in
                            await Task.yield()
                            #expect(TraceScope.current == span.context)
                            return span.context
                        }
                        #expect(TraceScope.current == root.context)
                        return child
                    }
                }
                var children: Set<SpanId> = []
                for await child in group {
                    #expect(child.traceParent.traceId == root.context.traceParent.traceId)
                    children.insert(child.traceParent.spanId)
                }
                #expect(children.count == 2)
                #expect(TraceScope.current == root.context)
            }
        }
        #expect(TraceScope.current == nil)
    }

    @Test("An async throw restores the caller's context and preserves actor-local results")
    @MainActor
    func asyncThrow() async throws {
        final class Draft { var edits = 0 }
        let draft = Draft()
        let result = try await withSpan("Edit") { root in
            let current = withSpan("Read") { $0.context }
            #expect(current.traceParent.traceId == root.context.traceParent.traceId)
            do {
                try await tracer.withSpan("Commit", ofKind: .internal, isolation: #isolation) { _ in
                    await Task.yield()
                    MainActor.assertIsolated()
                    draft.edits += 1
                    throw DraftError.invalid
                }
                Issue.record("Expected the edit to throw")
            } catch DraftError.invalid {
                #expect(TraceScope.current == root.context)
            }
            let record = try #require(exporter.records.first)
            #expect(record.parentSpanId == root.context.traceParent.spanId)
            #expect(record.error == ErrorInfo(DraftError.invalid))
            return draft
        }
        #expect(result === draft)
        #expect(result.edits == 1)
        #expect(TraceScope.current == nil)
    }
}
