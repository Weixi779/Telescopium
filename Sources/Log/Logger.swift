//
//  Logger.swift
//  Telescopium
//
//  Created by weixi on 2025/09/05.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Creates structured log records with source context and sends them to the selected recorder.
/// Message and per-call metadata expressions are evaluated once, on the caller, for accepted levels only.
/// All five levels capture the caller's file, function, line, and column and accept an optional error.
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
        msg: () -> String,
        error: (any Error)?,
        metadata: () -> [String: Any],
        file: StaticString,
        function: StaticString,
        line: Int,
        column: Int,
    ) {
        let configuration = Log.currentConfiguration
        let recorder = explicitRecorder ?? configuration.recorder
        guard recorder.isEnabled(for: level) else { return }

        var record = LogRecord(
            timestamp: Date(),
            level: level,
            category: category,
            subsystem: Self.subsystem,
            message: msg(),
            location: LogSourceLocation(
                fileID: String(describing: file),
                function: String(describing: function),
                line: line,
                column: column,
            ),
            error: error.map(ErrorInfo.init),
            metadata: defaultMetadata.merging(overrides: Metadata(converting: metadata())),
        )
        for enricher in configuration.enrichers {
            record = enricher.process(record)
        }
        recorder.record(record)
    }

    /// Logs an informational message.
    public func info(
        _ msg: @autoclosure () -> String,
        error: (any Error)? = nil,
        metadata: @autoclosure () -> [String: Any] = [:],
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

    /// Sends a debug record to the selected recorder.
    public func debug(
        _ msg: @autoclosure () -> String,
        error: (any Error)? = nil,
        metadata: @autoclosure () -> [String: Any] = [:],
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
        _ msg: @autoclosure () -> String,
        error: (any Error)? = nil,
        metadata: @autoclosure () -> [String: Any] = [:],
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
    public func error(
        _ msg: @autoclosure () -> String,
        error: (any Error)? = nil,
        metadata: @autoclosure () -> [String: Any] = [:],
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
        _ msg: @autoclosure () -> String,
        error: (any Error)? = nil,
        metadata: @autoclosure () -> [String: Any] = [:],
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
