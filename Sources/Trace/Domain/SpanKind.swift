//
//  SpanKind.swift
//  Telescopium
//
//  Created by weixi on 2026/11/23.
//  Copyright © 2026 Telescopium.
//

/// The role an operation plays in a trace.
public enum SpanKind: String, CaseIterable, Codable, Hashable, Sendable {
    /// Work within the application, such as coordinating a purchase.
    case `internal`

    /// Sends a request to a remote service and waits for its response.
    case client

    /// Handles an incoming request and returns a response to the caller.
    case server

    /// Submits work for asynchronous processing, such as publishing a message.
    case producer

    /// Processes work submitted by a producer, such as handling a queued message.
    case consumer
}
