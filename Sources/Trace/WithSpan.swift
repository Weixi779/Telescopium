//
//  WithSpan.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

public enum TraceScope {
    /// The innermost span context bound to the current task or synchronous call.
    @TaskLocal public static var current: SpanContext?
}

/// Runs a synchronous operation with a new current span and ends it when the operation exits.
public func withSpan<Result>(
    _ name: String,
    ofKind kind: SpanKind = .internal,
    _ operation: (any Span) throws -> Result,
) rethrows -> Result {
    try Trace.currentTracer.withSpan(name, ofKind: kind, operation)
}

/// Keeps the new span current across suspension and preserves the caller's actor isolation.
public func withSpan<Result>(
    _ name: String,
    ofKind kind: SpanKind = .internal,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: (any Span) async throws -> Result,
) async rethrows -> Result {
    try await Trace.currentTracer.withSpan(name, ofKind: kind, isolation: isolation, operation)
}

public extension Tracer {
    /// Runs the operation with a new span from this tracer and ends it when the operation exits.
    func withSpan<Result>(
        _ name: String,
        ofKind kind: SpanKind = .internal,
        _ operation: (any Telescopium.Span) throws -> Result,
    ) rethrows -> Result {
        let span = startSpan(name, ofKind: kind, parent: TraceScope.current)
        do {
            let result = try span.withCurrent {
                try operation(span)
            }
            endSpan(span, throwing: nil)
            return result
        } catch {
            endSpan(span, throwing: error)
            throw error
        }
    }

    /// Keeps this tracer's span current across suspension and preserves the caller's actor isolation.
    func withSpan<Result>(
        _ name: String,
        ofKind kind: SpanKind = .internal,
        isolation: isolated (any Actor)? = #isolation,
        _ operation: (any Telescopium.Span) async throws -> Result,
    ) async rethrows -> Result {
        let span = startSpan(name, ofKind: kind, parent: TraceScope.current)
        do {
            let result = try await span.withCurrent(isolation: isolation) {
                try await operation(span)
            }
            endSpan(span, throwing: nil)
            return result
        } catch {
            endSpan(span, throwing: error)
            throw error
        }
    }
}
