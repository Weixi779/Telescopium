//
//  MetadataConversionTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct MetadataConversionTests {
    @Test("Individual values use the same conversion as dictionary fields")
    func individualValues() {
        let nested: [Any] = [1, true, Date()]
        #expect(MetadataValue(converting: nested) == .array([1, true]))
        #expect(MetadataValue(converting: Date()) == nil)
    }

    @Test("Swift and Foundation values retain their numeric types")
    func numericTypes() throws {
        let decimal = try #require(Decimal(string: "1.0000000000000001"))
        let values: [Any] = [
            NSNumber(value: true), NSNumber(value: 0), NSNumber(value: 1), Int8(-1),
            UInt64(Int64.max), Float(1.25), Double(1.0), UInt64.max, decimal,
        ]
        let fields = Metadata(converting: ["values": values])
        #expect(fields["values"] == [true, 0, 1, -1, .int(.max), 1.25, 1.0])
    }

    @Test("Unsupported nested values are skipped and typed metadata passes through")
    func nestedFields() {
        let bytes = Data([0, 255])
        let raw: [String: Any] = [
            "items": [bytes, Date(), NSNull()] as [Any],
            "object": ["raw": MetadataValue.string("ready"), "unsupported": URL(fileURLWithPath: "/")],
            "typed": MetadataValue.object(["flags": [true]]),
            "emptyArray": [], "emptyObject": [:],
        ]
        #expect(Metadata(converting: raw) == [
            "items": [.bytes(bytes), .null], "object": ["raw": "ready"], "typed": ["flags": [true]],
            "emptyArray": [], "emptyObject": [:],
        ])
    }

    @Test("Foundation containers may be shared and cycles are skipped")
    func sharedAndCyclicContainers() {
        let object = NSMutableDictionary(dictionary: ["count": 1])
        let array = NSMutableArray(object: object)
        object["cycle"] = array
        defer { object.removeObject(forKey: "cycle") }

        let fields = Metadata(converting: ["left": object, "right": object])
        #expect(fields["left"] == ["count": 1, "cycle": []])
        #expect(fields["right"] == fields["left"])
    }
}
