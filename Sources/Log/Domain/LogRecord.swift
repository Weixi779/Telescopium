//
//  LogRecord.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// A structured log record for forwarding to external sinks.
public struct LogRecord: Sendable, Codable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let subsystem: String
    public let message: String
    public let location: LogSourceLocation
    public let error: LogErrorInfo?
    public let metadata: Metadata

    public init(
        timestamp: Date,
        level: LogLevel,
        category: String,
        subsystem: String,
        message: String,
        location: LogSourceLocation,
        error: LogErrorInfo? = nil,
        metadata: Metadata,
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.subsystem = subsystem
        self.message = message
        self.location = location
        self.error = error
        self.metadata = metadata
    }

    public func replacing(
        message: String? = nil,
        metadata: Metadata? = nil,
    ) -> LogRecord {
        LogRecord(
            timestamp: timestamp,
            level: level,
            category: category,
            subsystem: subsystem,
            message: message ?? self.message,
            location: location,
            error: error,
            metadata: metadata ?? self.metadata,
        )
    }
}
