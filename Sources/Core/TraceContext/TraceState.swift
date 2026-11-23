//
//  TraceState.swift
//  Telescopium
//
//  Created by weixi on 2026/11/23.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Ordered vendor entries from the W3C `tracestate` header, most recent first.
/// https://www.w3.org/TR/trace-context/#tracestate-header
public struct TraceState: Sendable, Hashable, Codable {
    public struct Entry: Sendable, Hashable {
        public let key: String
        public let value: String

        public init?(key: String, value: String) {
            // W3C permits a simple vendor key or a tenant@system key.
            let keyPattern = #/[a-z][a-z0-9_*/-]{0,255}|[a-z0-9][a-z0-9_*/-]{0,240}@[a-z][a-z0-9_*/-]{0,13}/#
            guard key.wholeMatch(of: keyPattern) != nil,
                  (1...256).contains(value.utf8.count),
                  value.utf8.allSatisfy({ (0x20...0x7E).contains($0) }),
                  !value.contains(","), !value.contains("="), value.last != " " else {
                return nil
            }
            self.key = key
            self.value = value
        }
    }

    private static let maximumMembers = 32
    public let entries: [Entry]

    public init() {
        entries = []
    }

    public init?(entries: [Entry]) {
        guard entries.count <= Self.maximumMembers,
              Set(entries.map(\.key)).count == entries.count else {
            return nil
        }
        self.entries = entries
    }

    /// Parses a combined header, preserving entry order and ignoring empty list members.
    public init?(headerValue: String) {
        let members = headerValue.split(
            separator: ",",
            maxSplits: Self.maximumMembers,
            omittingEmptySubsequences: false
        )
        guard members.count <= Self.maximumMembers else { return nil }

        var entries: [Entry] = []
        let whitespace = CharacterSet(charactersIn: " \t")
        for member in members {
            let text = member.trimmingCharacters(in: whitespace)
            if text.isEmpty { continue }
            guard let separator = text.firstIndex(of: "=") else { return nil }
            let key = String(text[..<separator])
            let value = String(text[text.index(after: separator)...])
            guard let entry = Entry(key: key, value: value) else { return nil }
            entries.append(entry)
        }
        self.init(entries: entries)
    }

    public subscript(key: String) -> String? {
        entries.first { $0.key == key }?.value
    }

    public var headerValue: String {
        entries.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let header = try container.decode(String.self)
        guard let state = TraceState(headerValue: header) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid W3C tracestate.")
        }
        self = state
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(headerValue)
    }
}
