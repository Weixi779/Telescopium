//
//  LogRecorder.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Applies redactors in order, then sends the resulting record to each exporter.
public struct LogRecorder: LogRecording {
    private let redactors: [any LogRedactor]
    private let exporters: [any LogExporter]

    public init(
        redactors: [any LogRedactor] = [],
        exporters: [any LogExporter] = [OSLogExporter()]
    ) {
        self.redactors = redactors
        self.exporters = exporters
    }

    public func record(_ record: LogRecord) {
        var output = record
        for redactor in redactors where redactor.policy.shouldRedact() {
            output = redactor.redact(output)
        }

        for exporter in exporters {
            exporter.export(output)
        }
    }
}
