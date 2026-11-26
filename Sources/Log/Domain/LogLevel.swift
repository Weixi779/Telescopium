//
//  LogLevel.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

/// The severity of a log record.
public enum LogLevel: String, CaseIterable, Codable, Hashable, Sendable {
    /// Detailed diagnostic messages
    case debug
    /// Informational messages
    case info
    /// Warnings about unexpected or recoverable conditions
    case warning
    /// Error messages for error conditions
    case error
    /// Faults indicating a potential bug or violated program invariant
    case fault
}

extension LogLevel: LosslessStringConvertible {
    public var description: String { rawValue }

    /// Parses a log level name case-insensitively.
    public init?(_ description: String) {
        self.init(rawValue: description.lowercased())
    }
}

extension LogLevel: Comparable {
    private var severityOrder: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .warning: 2
        case .error: 3
        case .fault: 4
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.severityOrder < rhs.severityOrder
    }
}
