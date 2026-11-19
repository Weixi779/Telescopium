//
//  LoggerSystem.swift
//  Telescopium
//
//  Created by weixi on 2026/04/27.
//  Copyright © 2026 Telescopium.
//

/// Global entry point for the logging system.
public enum LoggerSystem {
    private static let engine = LogSystemEngine()
    
    /// Restores the default OS log exporter and clears the redactors.
    public static func setup() {
        engine.setup(LogSystemState())
    }

    /// Replaces the current exporters and redactors. Pass an empty exporter list to disable output.
    public static func setup(
        exporters: [LogExporter],
        redactors: [LogRedactor] = []
    ) {
        engine.setup(LogSystemState(exporters: exporters, redactors: redactors))
    }
    
    /// Convenience setup for the common single-exporter case.
    public static func setup(
        exporter: LogExporter,
        redactors: [LogRedactor] = []
    ) {
        setup(exporters: [exporter], redactors: redactors)
    }

    /// Replaces the redactors while preserving the current exporters.
    public static func setup(redactors: [LogRedactor]) {
        engine.setRedactors(redactors)
    }
    
    public static func addExporter(_ exporter: LogExporter) {
        engine.addExporters([exporter])
    }
    
    public static func addExporters(_ exporters: [LogExporter]) {
        engine.addExporters(exporters)
    }
    
    public static func addRedactor(_ redactor: LogRedactor) {
        engine.addRedactors([redactor])
    }
    
    public static func addRedactors(_ redactors: [LogRedactor]) {
        engine.addRedactors(redactors)
    }
    
    public static func removeAllExporters() {
        engine.removeAllExporters()
    }
    
    public static func removeAllRedactors() {
        engine.removeAllRedactors()
    }
    
    static func emit(_ record: LogRecord) {
        engine.emit(record)
    }
}

private final class LogSystemEngine: Sendable {
    private let state = LockedValue(LogSystemState())
    
    func setup(_ configuration: LogSystemState) {
        state.withLock { $0 = configuration }
    }

    func setRedactors(_ redactors: [LogRedactor]) {
        state.withLock { $0.redactors = redactors }
    }
    
    func addExporters(_ exporters: [LogExporter]) {
        state.withLock {
            $0.exporters.append(contentsOf: exporters)
        }
    }
    
    func addRedactors(_ redactors: [LogRedactor]) {
        state.withLock {
            $0.redactors.append(contentsOf: redactors)
        }
    }
    
    func removeAllExporters() {
        state.withLock {
            $0.exporters.removeAll()
        }
    }
    
    func removeAllRedactors() {
        state.withLock {
            $0.redactors.removeAll()
        }
    }
    
    func emit(_ record: LogRecord) {
        let components = state.withLock { $0 }
        var output = record
        for redactor in components.redactors where redactor.policy.shouldRedact() {
            output = redactor.redact(output)
        }
        
        for exporter in components.exporters {
            exporter.export(output)
        }
    }
}

private struct LogSystemState: Sendable {
    var exporters: [LogExporter] = [OSLogExporter()]
    var redactors: [LogRedactor] = []
}
