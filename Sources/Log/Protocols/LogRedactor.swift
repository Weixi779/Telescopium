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

/// Scrubs sensitive data before export.
///
/// For each record, `LogRecorder` runs each enabled redactor once in configuration
/// order, passing its result to the next redactor. All exporters receive the final result.
public protocol LogRedactor: LogRecordProcessor {
    var policy: RedactionPolicy { get }
}

public extension LogRedactor {
    var policy: RedactionPolicy { .always }
}
