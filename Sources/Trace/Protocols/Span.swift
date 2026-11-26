//
//  Span.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

/// An operation in progress. Copies of a span refer to the same operation.
public protocol Span: Sendable {
    /// The stable identity and propagation state assigned when the span starts.
    var context: SpanContext { get }

    /// Sets or replaces one field on this span. Calls can overlap.
    func setMetadata(_ value: MetadataValue, forKey key: String)

    /// Appends an event in recording order, including repeated names.
    /// Calls can overlap. Events received after the span ends are ignored.
    func addEvent(_ event: SpanEvent)
}
