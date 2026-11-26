//
//  LogRecorder.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Applies redactors in order, then sends the resulting record to each exporter.
public struct LogRecorder: LogRecording {
    private let minimumLevel: LogLevel
    private let redactors: [any LogRedactor]
    private let exporters: [any LogExporter]

    public init(
        minimumLevel: LogLevel = .debug,
        redactors: [any LogRedactor] = [],
        exporters: [any LogExporter] = [OSLogExporter()],
    ) {
        self.minimumLevel = minimumLevel
        self.redactors = redactors
        self.exporters = exporters
    }

    /// Accepts records at or above the configured level when there is an export destination.
    public func isEnabled(for level: LogLevel) -> Bool {
        !exporters.isEmpty && level >= minimumLevel
    }

    public func record(_ record: LogRecord) {
        guard isEnabled(for: record.level) else { return }
        var output = record
        for redactor in redactors where redactor.policy.shouldRedact() {
            output = redactor.process(output)
        }

        for exporter in exporters {
            exporter.export(output)
        }
    }
}
