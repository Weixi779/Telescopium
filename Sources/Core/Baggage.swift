//
//  Baggage.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// Application-defined string properties associated with a workflow.
///
/// This is an in-memory value. It does not validate HTTP header syntax, encode
/// propagation headers, manage the active context, or attach properties to logs.
public struct Baggage: Sendable, Hashable, Codable {
    public let entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    public subscript(key: String) -> Entry? {
        entries[key]
    }

    /// Returns a new value, replacing both the value and metadata for an existing key.
    public func settingValue(_ value: String, forKey key: String, metadata: Metadata? = nil) -> Baggage {
        var entries = entries
        entries[key] = Entry(value: value, metadata: metadata)
        return Baggage(entries: entries)
    }

    /// Returns a new value without the entry. Removing an absent key has no effect.
    public func removingValue(forKey key: String) -> Baggage {
        var entries = entries
        entries.removeValue(forKey: key)
        return Baggage(entries: entries)
    }

    public struct Entry: Sendable, Hashable, Codable {
        public let value: String
        public let metadata: Metadata?

        public init(value: String, metadata: Metadata? = nil) {
            self.value = value
            self.metadata = metadata
        }
    }

    /// An opaque string whose interpretation belongs to the caller or propagator.
    public struct Metadata: Sendable, Hashable, Codable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
