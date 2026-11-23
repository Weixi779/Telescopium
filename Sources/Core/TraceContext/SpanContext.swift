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
        isRemote: Bool = false
    ) {
        self.traceParent = traceParent
        self.traceState = traceState
        self.isRemote = isRemote
    }
}
