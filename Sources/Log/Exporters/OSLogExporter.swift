//
//  OSLogExporter.swift
//  Telescopium
//
//  Created by weixi on 2026/11/19.
//  Copyright © 2026 Telescopium.
//

import os

/// Writes the message, optional error, and source location as private text in Apple's unified log.
public struct OSLogExporter: LogExporter {
    public init() {}

    public func export(_ record: LogRecord) {
        let logger = os.Logger(subsystem: record.subsystem, category: record.category)
        let level = record.level.osLogType
        guard logger.isEnabled(type: level) else { return }

        var message = record.message
        if let error = record.error {
            message += "\n\(error.typeName): \(error.message)"
        }
        let location = record.location
        message += "\n[\(location.fileID):\(location.line):\(location.column)] \(location.function)"

        logger.log(level: level, "\(message, privacy: .private)")
    }
}

private extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning, .error: .error
        case .fault: .fault
        }
    }
}
