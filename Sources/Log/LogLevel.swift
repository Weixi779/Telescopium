//
//  LogLevel.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

/// The severity of a log record.
public enum LogLevel: CaseIterable, Codable, Identifiable, Sendable {
    /// Debug messages (typically not persisted in release builds)
    case debug
    /// Informational messages
    case info
    /// Warnings about unexpected or recoverable conditions
    case warning
    /// Error messages for error conditions
    case error
    /// Faults indicating a potential bug or violated program invariant
    case fault

    public var id: Self { self }

    /// Human-readable display name for the log level.
    /// - Returns: Uppercase string representation of the log level
    public var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .fault: return "FAULT"
        }
    }
}
