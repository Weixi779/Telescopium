//
//  LogRecording.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Receives a logger's enriched record before redaction or export.
public protocol LogRecording: Sendable {
    /// Called synchronously on the logging caller's thread. Calls can overlap.
    func record(_ record: LogRecord)
}
