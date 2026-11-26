//
//  SpanRecord.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// A snapshot of a completed span for export.
public struct SpanRecord: Sendable, Equatable, Codable {
    public let name: String
    public let kind: SpanKind
    public let context: SpanContext
    public let parentSpanId: SpanId?
    /// Wall-clock timestamps for correlation with other events. System clock adjustments can affect their order.
    public let startTime: Date
    public let endTime: Date
    /// Elapsed time measured with a continuous clock, including time the system spent asleep.
    public let duration: Duration
    public let metadata: Metadata
    public let events: [SpanEvent]
    public let error: ErrorInfo?

    /// Creates a completed record with an independently measured duration and wall-clock timestamps.
    public init(
        name: String,
        kind: SpanKind,
        context: SpanContext,
        parentSpanId: SpanId? = nil,
        startTime: Date,
        endTime: Date,
        duration: Duration,
        metadata: Metadata = [:],
        events: [SpanEvent] = [],
        error: ErrorInfo? = nil,
    ) {
        self.name = name
        self.kind = kind
        self.context = context
        self.parentSpanId = parentSpanId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.metadata = metadata
        self.events = events
        self.error = error
    }
}
