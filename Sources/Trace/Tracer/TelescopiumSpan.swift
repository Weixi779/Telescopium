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
        let name: String
        let kind: SpanKind
        let parentSpanId: SpanId?
        let startTime: Date
        let startInstant: ContinuousClock.Instant
        var metadata: Metadata = [:]
        var events: [SpanEvent] = []
    }

    public let context: SpanContext
    /// Allocated only for recorded spans. The value inside is consumed by the first end.
    private let recording: LockedValue<Recording?>?

    init(context: SpanContext) {
        self.context = context
        recording = nil
    }

    init(
        name: String,
        kind: SpanKind,
        context: SpanContext,
        parentSpanId: SpanId?,
        startTime: Date = .now,
        startInstant: ContinuousClock.Instant = .now,
    ) {
        self.context = context
        let contents = Recording(
            name: name,
            kind: kind,
            parentSpanId: parentSpanId,
            startTime: startTime,
            startInstant: startInstant,
        )
        recording = LockedValue(contents)
    }

    public func setMetadata(_ value: MetadataValue, forKey key: String) {
        recording?.withLock { $0?.metadata[key] = value }
    }

    public func addEvent(_ event: SpanEvent) {
        recording?.withLock { $0?.events.append(event) }
    }

    func finishWithoutRecord() {
        _ = recording?.withLock { $0.take() }
    }

    func finish(throwing error: (any Error)?) -> SpanRecord? {
        guard let (contents, endTime, duration) = finishRecording() else { return nil }
        return SpanRecord(
            name: contents.name,
            kind: contents.kind,
            context: context,
            parentSpanId: contents.parentSpanId,
            startTime: contents.startTime,
            endTime: endTime,
            duration: duration,
            metadata: contents.metadata,
            events: contents.events,
            error: error.map(ErrorInfo.init),
        )
    }

    private func finishRecording() -> (Recording, Date, Duration)? {
        recording?.withLock { recording in
            guard let contents = recording.take() else { return nil }
            return (contents, .now, contents.startInstant.duration(to: .now))
        }
    }
}
