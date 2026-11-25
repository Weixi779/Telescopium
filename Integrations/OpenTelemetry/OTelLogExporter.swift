//
//  OTelLogExporter.swift
//  TelescopiumOpenTelemetry
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

#if OpenTelemetry
import OpenTelemetryApi
import Telescopium

/// Emits redacted records into the host's OpenTelemetry logging pipeline.
public struct OTelLogExporter: LogExporter {
    private let provider: any LoggerProvider

    public init(provider: any LoggerProvider) {
        self.provider = provider
    }

    public func export(_ record: LogRecord) {
        var attributes = record.metadata.mapValues(\.otelValue)
        attributes["telescopium.subsystem"] = .string(record.subsystem)
        attributes["code.file.path"] = .string(record.location.fileID)
        attributes["code.function.name"] = .string(record.location.function)
        attributes["code.line.number"] = .int(record.location.line)
        attributes["code.column.number"] = .int(record.location.column)
        if let error = record.error {
            attributes["exception.type"] = .string(error.typeName)
            attributes["exception.message"] = .string(error.message)
            attributes["telescopium.error.domain"] = error.domain.map(AttributeValue.string)
            attributes["telescopium.error.code"] = error.code.map(AttributeValue.int)
        }

        let logger = provider.get(instrumentationScopeName: record.category)
        var builder = logger.logRecordBuilder()
            .setTimestamp(record.timestamp)
            .setSeverity(record.level.otelSeverity)
            .setBody(.string(record.message))
            .setAttributes(attributes)
        if let parent = record.traceParent {
            builder = builder.setSpanContext(.create(
                traceId: .init(fromHexString: parent.traceId.hexString),
                spanId: .init(fromHexString: parent.spanId.hexString),
                traceFlags: .init(fromByte: parent.flags),
                traceState: .init(),
            ))
        }
        builder.emit()
    }
}

private extension MetadataValue {
    var otelValue: AttributeValue {
        switch self {
        case .null: .string("null")
        case let .bool(value): .bool(value)
        case let .int(value): Int(exactly: value).map(AttributeValue.int) ?? .string(String(value))
        case let .double(value): .double(value)
        case let .string(value): .string(value)
        case let .bytes(data): .string(data.base64EncodedString())
        case let .array(values): .array(AttributeArray(values: values.map(\.otelValue)))
        case let .object(fields): .set(AttributeSet(labels: fields.mapValues(\.otelValue)))
        }
    }
}

private extension LogLevel {
    var otelSeverity: Severity {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .warn
        case .error: .error
        case .fault: .error2
        }
    }
}
#endif
