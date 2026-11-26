//
//  Logger.swift
//  Telescopium
//
//  Created by weixi on 2025/09/05.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Creates structured log records with source context and sends them to the selected recorder.
public struct Logger: Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"
    public static let defaultCategory = "Default"
    private let category: String
    private let explicitRecorder: (any LogRecording)?

    /// Metadata applied to every record from this logger.
    private let defaultMetadata: Metadata

    /// Creates a logger whose default fields can be overridden per record.
    /// Supply a recorder to bind it to this logger. Omit it to follow the application recorder on each call.
    public init(
        category: String = Logger.defaultCategory,
        metadata: [String: Any] = [:],
        recorder: (any LogRecording)? = nil,
    ) {
        self.category = Self.normalizedCategory(category)
        self.defaultMetadata = Metadata(converting: metadata)
        self.explicitRecorder = recorder
    }

    private static func normalizedCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultCategory : trimmed
    }

    private func emitRecord(
        level: LogLevel,
        msg: String,
        error: (any Error)?,
        metadata: [String: Any],
        file: StaticString,
        function: StaticString,
        line: Int,
        column: Int,
    ) {
        var record = LogRecord(
            timestamp: Date(),
            level: level,
            category: category,
            subsystem: Self.subsystem,
            message: msg,
            location: LogSourceLocation(
                fileID: String(describing: file),
                function: String(describing: function),
                line: line,
                column: column,
            ),
            error: error.map(ErrorInfo.init),
            metadata: defaultMetadata.merging(overrides: Metadata(converting: metadata)),
        )
        let configuration = Log.currentConfiguration
        for enricher in configuration.enrichers {
            record = enricher.process(record)
        }
        let recorder = explicitRecorder ?? configuration.recorder
        recorder.record(record)
    }

    /// Logs an informational message.
    /// - Parameters:
    ///   - msg: The message to log
    ///   - error: An optional error to capture with this record
    ///   - metadata: Optional key-value pairs attached to the log record
    ///   - file: The file where the log is called (automatically captured)
    ///   - function: The function where the log is called (automatically captured)
    ///   - line: The line number where the log is called (automatically captured)
    ///   - column: The column where the log is called (automatically captured)
    public func info(
        _ msg: String,
        error: (any Error)? = nil,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        emitRecord(
            level: .info,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column,
        )
    }

    /// Logs a debug message. Debug logs are typically not persisted in release builds.
    /// - Parameters:
    ///   - msg: The message to log
    ///   - error: An optional error to capture with this record
    ///   - metadata: Optional key-value pairs attached to the log record
    ///   - file: The file where the log is called (automatically captured)
    ///   - function: The function where the log is called (automatically captured)
    ///   - line: The line number where the log is called (automatically captured)
    ///   - column: The column where the log is called (automatically captured)
    public func debug(
        _ msg: String,
        error: (any Error)? = nil,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        emitRecord(
            level: .debug,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column,
        )
    }

    /// Logs a warning about an unexpected or recoverable condition.
    public func warning(
        _ msg: String,
        error: (any Error)? = nil,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        emitRecord(
            level: .warning,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column,
        )
    }

    /// Logs an error message for error conditions and failures.
    /// - Parameters:
    ///   - msg: The message to log
    ///   - error: An optional error to capture with this record
    ///   - metadata: Optional key-value pairs attached to the log record
    ///   - file: The file where the log is called (automatically captured)
    ///   - function: The function where the log is called (automatically captured)
    ///   - line: The line number where the log is called (automatically captured)
    ///   - column: The column where the log is called (automatically captured)
    public func error(
        _ msg: String,
        error: (any Error)? = nil,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        emitRecord(
            level: .error,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column,
        )
    }

    /// Logs a potential bug, such as a violated program invariant.
    public func fault(
        _ msg: String,
        error: (any Error)? = nil,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line,
        column: Int = #column,
    ) {
        emitRecord(
            level: .fault,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column,
        )
    }
}
