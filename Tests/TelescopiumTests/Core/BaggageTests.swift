//
//  BaggageTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct BaggageTests {
    @Test("Empty baggage has no entries")
    func empty() {
        let baggage = Baggage()
        #expect(baggage.entries.isEmpty)
        #expect(baggage["missing"] == nil)
        #expect(baggage.removingValue(forKey: "missing") == baggage)
    }

    @Test("Setting and removing entries leave the original and other entries intact")
    func independentValues() {
        let original = Baggage(entries: ["region": .init(value: "cn")])
        let updated = original.settingValue("import", forKey: "workflow")
        let removed = updated.removingValue(forKey: "region")

        #expect(original.entries == ["region": .init(value: "cn")])
        #expect(updated["region"]?.value == "cn")
        #expect(updated["workflow"]?.value == "import")
        #expect(removed.entries == ["workflow": .init(value: "import")])
        #expect(updated.removingValue(forKey: "missing") == updated)
    }

    @Test("Replacing a key replaces its metadata too")
    func replacement() {
        let original = Baggage().settingValue("old", forKey: "workflow", metadata: .init(rawValue: "source=ios"))
        let updated = original.settingValue("new", forKey: "workflow", metadata: .init(rawValue: "source=macos"))
        let cleared = updated.settingValue("latest", forKey: "workflow")

        #expect(original["workflow"] == .init(value: "old", metadata: .init(rawValue: "source=ios")))
        #expect(updated["workflow"] == .init(value: "new", metadata: .init(rawValue: "source=macos")))
        #expect(cleared["workflow"] == .init(value: "latest"))
        #expect(cleared.entries.count == 1)
    }

    @Test("Keys and values preserve case, whitespace and Unicode")
    func stringsArePreserved() {
        let baggage = Baggage()
            .settingValue("B% 💼", forKey: "a")
            .settingValue("c", forKey: "A")
            .settingValue("  导入,流程;=  ", forKey: "业务 名称")
            .settingValue("", forKey: "empty")

        #expect(baggage["a"]?.value == "B% 💼")
        #expect(baggage["A"]?.value == "c")
        #expect(baggage["业务 名称"]?.value == "  导入,流程;=  ")
        #expect(baggage["empty"]?.value == "")
        #expect(baggage["Empty"] == nil)
    }

    @Test("Metadata is opaque and empty metadata differs from absent metadata")
    func opaqueMetadata() {
        let raw = "  source=ios;custom=💼  "
        let metadata = Baggage.Metadata(rawValue: raw)
        #expect(metadata.rawValue == raw)
        #expect(Baggage.Entry(value: "x", metadata: .init(rawValue: "")) != .init(value: "x"))
    }

    @Test("Equality and hashing include metadata and ignore insertion order")
    func equalityAndHashing() {
        let first = Baggage().settingValue("1", forKey: "a").settingValue("2", forKey: "b")
        let second = Baggage().settingValue("2", forKey: "b").settingValue("1", forKey: "a")
        let differentValue = first.settingValue("3", forKey: "a")
        let differentMetadata = first.settingValue("1", forKey: "a", metadata: .init(rawValue: "source=ios"))

        #expect(first == second)
        #expect(Set([first, second, differentValue, differentMetadata]).count == 3)
        #expect(Set([Baggage.Metadata(rawValue: "a"), .init(rawValue: "a"), .init(rawValue: "b")]).count == 2)
        #expect(Set([Baggage.Entry(value: "x"), .init(value: "x"), .init(value: "y")]).count == 2)
    }

    @Test("Codable preserves entries, absent metadata and opaque strings")
    func codingRoundTrip() throws {
        let metadata = Baggage.Metadata(rawValue: "  source=ios;custom=💼  ")
        let entry = Baggage.Entry(value: "B% 💼,;=", metadata: metadata)
        let baggage = Baggage(entries: [
            "业务": entry,
            "empty": .init(value: ""),
            "emptyMetadata": .init(value: "x", metadata: .init(rawValue: ""))
        ])
        try roundTrip(baggage)
        try roundTrip(Baggage())
        try roundTrip(entry)
        try roundTrip(metadata)

        let fixture = Data(#"{"entries":{"region":{"value":"cn"},"workflow":{"value":"import","metadata":{"rawValue":"source=ios"}}}}"#.utf8)
        let decoded = try JSONDecoder().decode(Baggage.self, from: fixture)
        #expect(decoded["region"] == .init(value: "cn"))
        #expect(decoded["workflow"] == .init(value: "import", metadata: .init(rawValue: "source=ios")))
    }

    @Test("Codable rejects values outside the string-based model", arguments: [
        #"{"entries":{"key":{"value":42}}}"#,
        #"{"entries":{"key":{}}}"#,
        #"{"entries":{"key":{"value":"x","metadata":{"rawValue":true}}}}"#
    ])
    func invalidCoding(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Baggage.self, from: Data(json.utf8))
        }
    }

    private func roundTrip<Value: Codable & Equatable>(_ value: Value) throws {
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(Value.self, from: data) == value)
    }
}
