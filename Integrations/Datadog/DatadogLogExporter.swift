//
//  DatadogLogExporter.swift
//  TelescopiumDatadog
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

#if Datadog
import DatadogLogs
import Telescopium

private struct RecordContext: Encodable {
    let category: String
    let subsystem: String
    let timestampMilliseconds: Int64?
    let location: LogSourceLocation
    let error: LogErrorInfo?

    enum CodingKeys: String, CodingKey {
        case category, subsystem, location, error
        case timestampMilliseconds = "timestamp_ms"
    }
}

/// Forwards redacted records to a logger created by the host after enabling Datadog Logs.
public struct DatadogLogExporter: LogExporter {
    private let logger: any LoggerProtocol

    public init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    public func export(_ record: LogRecord) {
        var attributes: [String: any Encodable] = record.metadata.mapValues(DatadogMetadataValue.init)
        attributes["telescopium"] = RecordContext(
            category: record.category,
            subsystem: record.subsystem,
            timestampMilliseconds: Int64(exactly: (record.timestamp.timeIntervalSince1970 * 1000).rounded(.down)),
            location: record.location,
            error: record.error
        )
        logger.log(
            level: record.level.datadogLevel,
            message: record.message,
            error: nil,
            attributes: attributes
        )
    }
}

private extension Telescopium.LogLevel {
    var datadogLevel: DatadogLogs.LogLevel {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .warn
        case .error: .error
        case .fault: .critical
        }
    }
}
#endif
