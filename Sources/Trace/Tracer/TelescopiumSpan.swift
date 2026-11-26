//
//  TelescopiumSpan.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// An operation recorded by `TelescopiumTracer`. All holders update the same span.
public final class TelescopiumSpan: Span {
    private struct Recording: Sendable {
        var metadata: Metadata = [:]
        var events: [SpanEvent] = []
    }

    public let context: SpanContext
    private let name: String
    private let kind: SpanKind
    private let parentSpanId: SpanId?
    private let startTime: Date
    private let startInstant: ContinuousClock.Instant
    private let recording = LockedValue<Recording?>(Recording())

    init(
        name: String,
        kind: SpanKind,
        parent: SpanContext?,
        startTime: Date = .now,
        startInstant: ContinuousClock.Instant = .now,
    ) {
        self.name = name
        self.kind = kind
        self.startTime = startTime
        self.startInstant = startInstant
        parentSpanId = parent?.traceParent.spanId
        context = parent?.child() ?? .root()
    }

    public func setMetadata(_ value: MetadataValue, forKey key: String) {
        recording.withLock { $0?.metadata[key] = value }
    }

    public func addEvent(_ event: SpanEvent) {
        recording.withLock { $0?.events.append(event) }
    }

    func finishWithoutRecord() {
        _ = recording.withLock { $0.take() }
    }

    func finish(throwing error: (any Error)?) -> SpanRecord? {
        guard let (contents, endTime, duration) = finishRecording() else { return nil }
        return SpanRecord(
            name: name,
            kind: kind,
            context: context,
            parentSpanId: parentSpanId,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            metadata: contents.metadata,
            events: contents.events,
            error: error.map(ErrorInfo.init),
        )
    }

    private func finishRecording() -> (Recording, Date, Duration)? {
        recording.withLock { recording in
            guard let contents = recording.take() else { return nil }
            return (contents, .now, startInstant.duration(to: .now))
        }
    }
}
