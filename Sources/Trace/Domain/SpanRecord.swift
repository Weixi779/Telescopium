//
//  SpanRecord.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// A snapshot of a completed `TelescopiumSpan`, delivered to the tracer's finish callback.
public struct SpanRecord: Sendable {
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
}
