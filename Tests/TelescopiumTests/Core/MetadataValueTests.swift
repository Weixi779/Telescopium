//
//  MetadataValueTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct MetadataValueTests {
    @Test("Nested metadata preserves field types, keys, order and empty values")
    func recursiveRoundTrip() throws {
        let fields: Metadata = [
            "attempts": [
                ["bytes": .bytes(Data([0xff])), "base64": "/w=="],
                [1, 1.0, true, .null, [], [:]],
            ],
            "bounds": [.int(.min), .int(.max)],
            "some_key": .null,
            "someKey": "present",
        ]
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = try encoder.encode(MetadataValue.object(fields))
        #expect(try decoder.decode(MetadataValue.self, from: data) == .object(fields))
    }

    @Test("Stored metadata uses one explicit type tag per node")
    func storageFormat() throws {
        let value: MetadataValue = [1, 1.0, .bytes(Data([0x61])), "YQ==", .null, [:]]
        let fixture = #"{"array":[{"int":1},{"double":1},{"bytes":"YQ=="},{"string":"YQ=="},{"null":null},{"object":{}}]}"#
        let data = Data(fixture.utf8)
        #expect(try JSONDecoder().decode(MetadataValue.self, from: data) == value)
        let encoded = try JSONEncoder().encode(value)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        #expect(try object.isEqual(JSONSerialization.jsonObject(with: data)))
    }

    @Test("Nonfinite double values survive default JSON encoding")
    func nonfiniteDoubles() throws {
        for original in [Double.infinity, -.infinity, .nan] {
            let data = try JSONEncoder().encode(MetadataValue.double(original))
            let result = try JSONDecoder().decode(MetadataValue.self, from: data)
            guard case .double(let value) = result else {
                Issue.record("Expected a double, got \(result)")
                continue
            }
            #expect(original.isNaN ? value.isNaN : value == original)
        }
    }

    @Test(
        "Invalid metadata tags and payloads fail decoding",
        arguments: [
            #"{}"#, #"{"other":1}"#, #"{"int":1,"bool":true}"#, #"{"null":false}"#,
            #"{"array":[{"bytes":"??"}]}"#, #"{"object":{"value":{"double":"oops"}}}"#,
        ],
    )
    func invalidEncoding(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MetadataValue.self, from: Data(json.utf8))
        }
    }
}
