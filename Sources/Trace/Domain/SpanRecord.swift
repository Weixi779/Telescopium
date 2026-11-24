//
//  SpanRecord.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// The same record accumulates metadata during the operation and freezes on exit.
final class SpanRecord: Span {
    struct State: Sendable {
        var metadata: Metadata = [:]
        var endTime: Date?
        var error: (any Error)?
    }

    let name: String
    let kind: SpanKind
    let context: SpanContext
    let parentSpanId: SpanId?
    let startTime = Date()
    private let storage = LockedValue(State())

    var state: State {
        storage.withLock { $0 }
    }

    init(name: String, kind: SpanKind, parent: SpanContext?) {
        self.name = name
        self.kind = kind
        parentSpanId = parent?.traceParent.spanId

        if let parent {
            let traceParent = TraceParent(
                traceId: parent.traceParent.traceId,
                spanId: .random(),
                flags: parent.traceParent.flags,
            )
            context = SpanContext(traceParent: traceParent, traceState: parent.traceState)
        } else {
            context = SpanContext(traceParent: .random())
        }
    }

    func setMetadata(_ value: MetadataValue, forKey key: String) {
        storage.withLock { state in
            guard state.endTime == nil else { return }
            state.metadata[key] = value
        }
    }

    func end(throwing error: (any Error)? = nil) {
        storage.withLock { state in
            guard state.endTime == nil else { return }
            state.endTime = Date()
            state.error = error
        }
    }
}
