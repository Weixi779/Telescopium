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
    func constructRecord() {
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
    }
}
