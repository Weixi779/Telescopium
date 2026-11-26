//
//  TelescopiumTracer.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

/// Creates spans and delivers their completed records.
public struct TelescopiumTracer: Tracer {
    private let exporter: (any SpanExporter)?

    /// With an exporter, the first end of each span exports its record synchronously after releasing the span's lock.
    /// With no exporter, ending a span only closes its recording.
    public init(exporter: (any SpanExporter)? = nil) {
        self.exporter = exporter
    }

    public func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> TelescopiumSpan {
        TelescopiumSpan(name: name, kind: kind, parent: parent)
    }

    public func endSpan(_ span: TelescopiumSpan, throwing error: (any Error)?) {
        guard let exporter else {
            span.finishWithoutRecord()
            return
        }
        guard let record = span.finish(throwing: error) else { return }
        exporter.export(record)
    }
}
