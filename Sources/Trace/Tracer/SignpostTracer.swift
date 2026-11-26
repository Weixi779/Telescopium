//
//  SignpostTracer.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

import os

private struct SignpostTracer<Base: Tracer>: Tracer {
    struct Span: Telescopium.Span {
        let base: Base.Span
        let interval: OSSignpostIntervalState?
        private let hasEnded = LockedValue(false)

        var context: SpanContext { base.context }

        func claimEnd() -> Bool {
            hasEnded.withLock { ended in
                guard !ended else { return false }
                ended = true
                return true
            }
        }

        func setMetadata(_ value: MetadataValue, forKey key: String) {
            base.setMetadata(value, forKey: key)
        }

        func addEvent(_ event: SpanEvent) {
            base.addEvent(event)
        }
    }

    let base: Base
    let signposter: OSSignposter

    func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> Span {
        let span = base.startSpan(name, ofKind: kind, parent: parent)
        guard signposter.isEnabled else { return Span(base: span, interval: nil) }

        let interval = signposter.beginInterval(
            "Span",
            id: signposter.makeSignpostID(),
            "\(name, privacy: .public)",
        )
        return Span(base: span, interval: interval)
    }

    func endSpan(_ span: Span, throwing error: (any Error)?) {
        guard span.claimEnd() else { return }
        if let interval = span.interval {
            signposter.endInterval("Span", interval)
        }
        base.endSpan(span.base, throwing: error)
    }
}

public extension Tracer {
    /// Emits an Instruments interval for each span while the supplied signposter is enabled.
    /// The signposter supplies the subsystem and category. Span names appear in its public message.
    func signposted(by signposter: OSSignposter) -> some Tracer {
        SignpostTracer(base: self, signposter: signposter)
    }
}
