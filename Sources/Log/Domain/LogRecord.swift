//
//  LogRecord.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// A structured log record for forwarding to external sinks.
public struct LogRecord: Sendable, Equatable, Codable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let subsystem: String
    public var message: String
    public let location: LogSourceLocation
    public let error: ErrorInfo?
    public var metadata: Metadata
    /// Identifies the span associated with this record at the logging call site.
    public var traceParent: TraceParent?

    public init(
        timestamp: Date,
        level: LogLevel,
        category: String,
        subsystem: String,
        message: String,
        location: LogSourceLocation,
        error: ErrorInfo? = nil,
        metadata: Metadata,
        traceParent: TraceParent? = nil,
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.subsystem = subsystem
        self.message = message
        self.location = location
        self.error = error
        self.metadata = metadata
        self.traceParent = traceParent
    }
}
