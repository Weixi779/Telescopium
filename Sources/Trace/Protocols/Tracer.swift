//
//  Tracer.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

/// Creates and ends the concrete spans used by a tracing implementation.
public protocol Tracer: Sendable {
    associatedtype Span: Telescopium.Span

    /// Starts an operation with the parent context currently bound to the caller.
    func startSpan(_ name: String, ofKind kind: SpanKind, parent: SpanContext?) -> Span

    /// Ends a span created by this tracer with the error thrown by its operation, if any.
    func endSpan(_ span: Span, throwing error: (any Error)?)
}
