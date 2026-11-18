//
//  LogExporter.swift
//  Telescopium
//
//  Created by weixi on 2026/01/04.
//  Copyright © 2026 Telescopium.
//

/// Receives each record after the configured redactors have run.
public protocol LogExporter {
    /// Called synchronously on the logging caller's thread, potentially from multiple threads at once.
    func export(_ record: LogRecord)
}
