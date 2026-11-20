//
//  Logger.swift
//  Telescopium
//
//  Created by weixi on 2025/09/05.
//  Copyright © 2026 Telescopium.
//

import os
import OSLog
import Foundation

/// Creates structured records with source context and measures intervals with OSSignposter.
public struct Logger: @unchecked Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"
    public static let defaultCategory = "Default"
    private let signposter: OSSignposter
    private let category: String
    private let explicitRecorder: (any LogRecording)?

    /// Metadata applied to every record from this logger.
    private let defaultMetadata: Metadata

    /// Creates a logger whose default fields can be overridden per record.
    /// Supply a recorder to bind it to this logger. Omit it to follow the application recorder on each call.
    public init(
        category: String = Logger.defaultCategory,
        metadata: [String: Any] = [:],
        recorder: (any LogRecording)? = nil
    ) {
        let normalizedCategory = Logger.normalizedCategory(category)
        let signpostLogger = os.Logger(subsystem: Self.subsystem, category: normalizedCategory)
        self.signposter = OSSignposter(logger: signpostLogger)
        self.category = normalizedCategory
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
        column: Int
    ) {
        let record = LogRecord(
            timestamp: Date(),
            level: level,
            category: category,
            subsystem: Self.subsystem,
            message: msg,
            location: LogSourceLocation(
                fileID: String(describing: file),
                function: String(describing: function),
                line: line,
                column: column
            ),
            error: error.map(LogErrorInfo.init),
            metadata: defaultMetadata.merging(overrides: Metadata(converting: metadata))
        )
        let recorder = explicitRecorder ?? Log.currentRecorder
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
        column: Int = #column
    ) {
        emitRecord(
            level: .info,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column
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
        column: Int = #column
    ) {
        emitRecord(
            level: .debug,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column
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
        column: Int = #column
    ) {
        emitRecord(
            level: .warning,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column
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
        column: Int = #column
    ) {
        emitRecord(
            level: .error,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column
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
        column: Int = #column
    ) {
        emitRecord(
            level: .fault,
            msg: msg,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
    
    // MARK: - Timer/Performance Measurement
    
    /// Starts a performance measurement interval that can be ended manually.
    /// Use this for complex scenarios where you need fine-grained control over timing.
    /// - Parameter name: A unique name for this measurement interval
    /// - Returns: OSSignpostIntervalState that must be passed to endInterval()
    /// - Note: Always pair with endInterval() to complete the measurement
    public func startInterval(_ name: StaticString) -> OSSignpostIntervalState {
        let intervalId = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: intervalId)
        return state
    }
    
    /// Ends a performance measurement interval started with startInterval().
    /// - Parameters:
    ///   - name: The name of the interval (must exactly match the name used in startInterval)
    ///   - state: The OSSignpostIntervalState returned from the corresponding startInterval() call
    public func endInterval(_ name: StaticString, state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }
    
    /// Measures the execution time of a synchronous closure.
    /// This is the recommended way to measure performance for most use cases.
    /// - Parameters:
    ///   - name: A descriptive name for this measurement
    ///   - operation: The closure whose execution time will be measured
    /// - Returns: The result returned by the operation closure
    /// - Throws: Re-throws any error thrown by the operation closure
    public func measure<T>(_ name: StaticString, operation: () throws -> T) rethrows -> T {
        let intervalId = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: intervalId)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            signposter.endInterval(name, state)
            info("📊 \(name) completed in \(String(format: "%.2f", duration * 1000))ms")
        }
        
        return try operation()
    }
    
    /// Measures the execution time of an asynchronous closure.
    /// Perfect for measuring async/await operations and Task execution times.
    /// - Parameters:
    ///   - name: A descriptive name for this measurement
    ///   - operation: The async closure whose execution time will be measured
    /// - Returns: The result returned by the operation closure
    /// - Throws: Re-throws any error thrown by the operation closure
    public func measureAsync<T>(_ name: StaticString, operation: () async throws -> T) async rethrows -> T {
        let intervalId = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: intervalId)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            signposter.endInterval(name, state)
            info("📊 \(name) completed in \(String(format: "%.2f", duration * 1000))ms")
        }
        
        return try await operation()
    }
    
    /// Emits an instant signpost event marker.
    /// Useful for marking specific points in time during execution for debugging and profiling.
    /// - Parameters:
    ///   - name: A descriptive name for this event
    ///   - message: Optional additional information about the event
    public func event(_ name: StaticString, _ message: String = "") {
        if message.isEmpty {
            signposter.emitEvent(name)
        } else {
            signposter.emitEvent(name, "\(message, privacy: .private)")
        }
    }
}
