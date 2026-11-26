//
//  SpanEvent.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// A named occurrence during a span, with its own timestamp and metadata.
public struct SpanEvent: Sendable, Equatable {
    public let name: String
    public let timestamp: Date
    public let metadata: Metadata

    public init(_ name: String, timestamp: Date = Date(), metadata: Metadata = [:]) {
        self.name = name
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
