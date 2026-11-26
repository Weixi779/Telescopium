//
//  LogRecordProcessor.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

/// Transforms a log record synchronously. Calls for different records may overlap.
public protocol LogRecordProcessor: Sendable {
    /// Returns the record to pass to the next processor or consumer.
    func process(_ record: LogRecord) -> LogRecord
}
