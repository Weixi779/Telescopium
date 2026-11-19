//
//  LogRedactor.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

/// Controls when a redactor is applied.
public enum RedactionPolicy: Sendable {
    case never
    case always
    case when(@Sendable () -> Bool)
    
    func shouldRedact() -> Bool {
        switch self {
        case .never:
            return false
        case .always:
            return true
        case let .when(condition):
            return condition()
        }
    }
}

/// Scrubs sensitive data from log records.
public protocol LogRedactor: Sendable {
    var policy: RedactionPolicy { get }
    /// May be called concurrently. Returns the record passed to subsequent redactors and sinks.
    func redact(_ record: LogRecord) -> LogRecord
}

public extension LogRedactor {
    var policy: RedactionPolicy { .always }
}
