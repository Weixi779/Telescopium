//
//  SpanContext.swift
//  Telescopium
//
//  Created by weixi on 2026/11/23.
//  Copyright © 2026 Telescopium.
//

/// A span's identity and the vendor state it carries across process boundaries.
public struct SpanContext: Sendable, Hashable, Codable {
    public let traceParent: TraceParent
    public let traceState: TraceState

    /// True for an identity extracted from a remote caller. A new local child has its own local identity.
    public let isRemote: Bool

    public init(
        traceParent: TraceParent,
        traceState: TraceState = TraceState(),
        isRemote: Bool = false,
    ) {
        self.traceParent = traceParent
        self.traceState = traceState
        self.isRemote = isRemote
    }

    /// Creates a local root context with fresh identifiers, zero flags, and empty vendor state.
    public static func root() -> SpanContext {
        SpanContext(traceParent: .random())
    }

    /// Derives a local context with a fresh span ID, inheriting the trace ID, flags, and vendor state.
    public func child() -> SpanContext {
        SpanContext(traceParent: traceParent.child(), traceState: traceState)
    }
}
