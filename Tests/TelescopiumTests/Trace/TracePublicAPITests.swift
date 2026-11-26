//
//  TracePublicAPITests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

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
}
