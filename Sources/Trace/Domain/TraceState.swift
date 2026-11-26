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
public struct TraceState: Sendable, Hashable {
    public struct Entry: Sendable, Hashable {
        // W3C permits a simple vendor key or a tenant@system key.
        // Regex<Substring> is not Sendable. A computed property keeps the matcher local to each use.
        private static var keyPattern: Regex<Substring> {
            #/[a-z][a-z0-9_*/-]{0,255}|[a-z0-9][a-z0-9_*/-]{0,240}@[a-z][a-z0-9_*/-]{0,13}/#
        }

        public let key: String
        public let value: String

        public init?(key: String, value: String) {
            guard key.wholeMatch(of: Self.keyPattern) != nil,
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
        self.init(validatedEntries: [])
    }

    public init?(entries: [Entry]) {
        guard entries.count <= Self.maximumMembers,
              Set(entries.map(\.key)).count == entries.count else {
            return nil
        }
        self.init(validatedEntries: entries)
    }

    private init(validatedEntries: [Entry]) {
        entries = validatedEntries
    }

    public subscript(key: String) -> String? {
        entries.first { $0.key == key }?.value
    }

    /// Returns a copy with the entry first, or nil if its key or value is invalid.
    /// Adding a new key to a full list drops the rightmost entry.
    public func settingValue(_ value: String, forKey key: String) -> TraceState? {
        guard let entry = Entry(key: key, value: value) else { return nil }
        var updated = entries.filter { $0.key != key }
        if updated.count == Self.maximumMembers {
            updated.removeLast()
        }
        updated.insert(entry, at: 0)
        return TraceState(validatedEntries: updated)
    }

    /// Returns a copy without the key, preserving the order of the remaining entries.
    public func removingValue(forKey key: String) -> TraceState {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return self }
        var updated = entries
        updated.remove(at: index)
        return TraceState(validatedEntries: updated)
    }

    // MARK: - W3C Header

    /// Parses a combined header, preserving entry order and ignoring empty list members.
    public init?(headerValue: String) {
        let members = headerValue.split(
            separator: ",",
            maxSplits: Self.maximumMembers,
            omittingEmptySubsequences: false,
        )
        guard members.count <= Self.maximumMembers else { return nil }

        var entries: [Entry] = []
        let whitespace = CharacterSet(charactersIn: " \t")
        for member in members {
            let text = member.trimmingCharacters(in: whitespace)
            if text.isEmpty { continue }
            guard let entry = Entry(headerMember: text) else { return nil }
            entries.append(entry)
        }
        self.init(entries: entries)
    }

    public var headerValue: String {
        entries.map(\.headerMember).joined(separator: ",")
    }
}

fileprivate extension TraceState.Entry {
    init?(headerMember: String) {
        guard let separator = headerMember.firstIndex(of: "=") else { return nil }
        let key = String(headerMember[..<separator])
        let value = String(headerMember[headerMember.index(after: separator)...])
        self.init(key: key, value: value)
    }

    var headerMember: String { "\(key)=\(value)" }
}

extension TraceState: Codable {
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
