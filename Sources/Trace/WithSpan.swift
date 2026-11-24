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
    _ operation: (any Span) throws -> Result
) rethrows -> Result {
    let span = SpanRecord(name: name, kind: kind, parent: TraceScope.current)
    do {
        let result = try TraceScope.$current.withValue(span.context) {
            try operation(span)
        }
        span.end()
        return result
    } catch {
        span.end(throwing: error)
        throw error
    }
}

/// Keeps the new span current across suspension and preserves the caller's actor isolation.
public func withSpan<Result>(
    _ name: String,
    ofKind kind: SpanKind = .internal,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: (any Span) async throws -> Result
) async rethrows -> Result {
    let span = SpanRecord(name: name, kind: kind, parent: TraceScope.current)
    do {
        let result = try await TraceScope.$current.withValue(span.context) {
            try await operation(span)
        }
        span.end()
        return result
    } catch {
        span.end(throwing: error)
        throw error
    }
}
