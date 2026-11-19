//
//  OSLogExporter.swift
//  Telescopium
//
//  Created by weixi on 2026/11/19.
//  Copyright © 2026 Telescopium.
//

import os

/// Writes log records to Apple's unified logging system.
public struct OSLogExporter: LogExporter {
    public init() {}

    public func export(_ record: LogRecord) {
        let logger = os.Logger(subsystem: record.subsystem, category: record.category)
        var message = record.message
        if let error = record.error {
            message += "\n\(error.typeName): \(error.message)"
        }
        let location = record.location
        message += "\n[\(location.fileID):\(location.line):\(location.column)] \(location.function)"

        switch record.level {
        case .debug:
            logger.debug("\(message, privacy: .private)")
        case .info:
            logger.info("\(message, privacy: .private)")
        case .warning, .error:
            logger.error("\(message, privacy: .private)")
        case .fault:
            logger.fault("\(message, privacy: .private)")
        }
    }
}
