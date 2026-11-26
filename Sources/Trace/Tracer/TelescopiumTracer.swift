//
//  TelescopiumTracer.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

/// Creates spans and delivers their completed records.
public struct TelescopiumTracer: Tracer {
    private let onFinish: (@Sendable (SpanRecord) -> Void)?

    /// The first end of each span calls `onFinish` synchronously, after releasing the span's lock.
    /// Callbacks for different spans can overlap. With no callback, ending a span only closes its recording.
    public init(onFinish: (@Sendable (SpanRecord) -> Void)? = nil) {
        self.onFinish = onFinish
    }

    public func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> TelescopiumSpan {
        TelescopiumSpan(name: name, kind: kind, parent: parent)
    }

    public func endSpan(_ span: TelescopiumSpan, throwing error: (any Error)?) {
        guard let onFinish else {
            span.finishWithoutRecord()
            return
        }
        guard let record = span.finish(throwing: error) else { return }
        onFinish(record)
    }
}
