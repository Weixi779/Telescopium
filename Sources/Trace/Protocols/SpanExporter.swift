//
//  SpanExporter.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

/// Receives completed span records through a tracer's finish callback.
public protocol SpanExporter: Sendable {
    /// Called synchronously on the thread ending the span. Calls for different spans can overlap.
    func export(_ record: SpanRecord)
}
