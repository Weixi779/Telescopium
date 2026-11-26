//
//  WithCurrent.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

public extension Span {
    /// Makes this span's context current for the operation and restores the previous context on exit.
    /// The caller retains responsibility for ending the span.
    func withCurrent<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try TraceScope.$current.withValue(context, operation: operation)
    }

    /// Keeps this span's context current across suspension, preserving the caller's actor isolation.
    /// Returning or throwing restores the previous context and leaves the span's lifetime to its owner.
    func withCurrent<Result>(
        isolation: isolated (any Actor)? = #isolation,
        _ operation: () async throws -> Result,
    ) async rethrows -> Result {
        try await TraceScope.$current.withValue(context) {
            try await operation()
        }
    }
}
