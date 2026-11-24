//
//  TraceParentTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct TraceParentTests {
    private static let trace = "4bf92f3577b34da6a3ce929d0e0e4736"
    private static let span = "00f067aa0ba902b7"
    private static let header = "00-\(trace)-\(span)-01"

    @Test("W3C example parses and serializes exactly")
    func w3cExample() throws {
        let parent = try #require(TraceParent(headerValue: Self.header))
        #expect(parent.traceId.hexString == Self.trace)
        #expect(parent.spanId.hexString == Self.span)
        #expect(parent.flags == 1)
        #expect(parent.headerValue == Self.header)
        #expect(parent == TraceParent(traceId: parent.traceId, spanId: parent.spanId, flags: 1))
        #expect(Set([parent, parent]).count == 1)
    }

    @Test(
        "Identifier boundaries retain leading zeros",
        arguments: [
            "00000000000000000000000000000001",
            "00000000000000010000000000000000",
            "ffffffffffffffffffffffffffffffff",
        ],
    )
    func traceBoundaries(_ string: String) throws {
        let id = try #require(TraceId(hexString: string))
        #expect(id.hexString == string)
    }

    @Test(
        "Span boundaries retain leading zeros",
        arguments: [
            "0000000000000001", "ffffffffffffffff",
        ],
    )
    func spanBoundaries(_ string: String) throws {
        let id = try #require(SpanId(hexString: string))
        #expect(id.hexString == string)
    }

    @Test(
        "Invalid trace identifiers are rejected",
        arguments: [
            "", "00000000000000000000000000000000",
            "4BF92F3577B34DA6A3CE929D0E0E4736",
            "gbf92f3577b34da6a3ce929d0e0e4736",
            "4bf92f3577b34da6a3ce929d0e0e473",
            "04bf92f3577b34da6a3ce929d0e0e4736",
            "4bf92f3577b34da6a3ce929d0e0e473 ",
            "é000000000000000000000000000000",
        ],
    )
    func invalidTrace(_ string: String) {
        #expect(TraceId(hexString: string) == nil)
    }

    @Test(
        "Invalid span identifiers are rejected",
        arguments: [
            "", "0000000000000000", "00F067AA0BA902B7", "g0f067aa0ba902b7",
            "0f067aa0ba902b7", "000f067aa0ba902b7", "00f067aa0ba902b ",
            "é00000000000000"
        ],
    )
    func invalidSpan(_ string: String) {
        #expect(SpanId(hexString: string) == nil)
    }

    @Test(
        "Malformed or unsupported headers are rejected",
        arguments: [
            "", "01-\(trace)-\(span)-01", "ff-\(trace)-\(span)-01",
            "00-00000000000000000000000000000000-\(span)-01",
            "00-\(trace)-0000000000000000-01",
            "00-\(trace.uppercased())-\(span)-01",
            "00-\(trace)-\(span.uppercased())-01",
            "00-\(trace)-\(span)-0A", "00-\(trace)-\(span)-gg",
            "00-\(trace)-\(span)-1", "00-\(trace)-\(span)-001",
            "00-\(trace)-\(span)-01-extra", " \(header)", "\(header)\n",
            "00_\(trace)-\(span)-01", "00-\(trace)--01"
        ],
    )
    func invalidHeader(_ string: String) {
        #expect(TraceParent(headerValue: string) == nil)
    }

    @Test("All flag bytes are preserved")
    func flagsRoundTrip() throws {
        let trace = try #require(TraceId(hexString: Self.trace))
        let span = try #require(SpanId(hexString: Self.span))
        for flags in UInt8.min...UInt8.max {
            let parent = TraceParent(traceId: trace, spanId: span, flags: flags)
            #expect(parent.headerValue.utf8.count == 55)
            #expect(TraceParent(headerValue: parent.headerValue) == parent)
        }
    }

    @Test("Codable uses validated single strings")
    func codable() throws {
        let parent = try #require(TraceParent(headerValue: Self.header))
        try checkCoding(parent, string: Self.header)
        try checkCoding(parent.traceId, string: Self.trace)
        try checkCoding(parent.spanId, string: Self.span)
    }

    private func checkCoding<Value: Codable & Equatable>(_ value: Value, string: String) throws {
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(String.self, from: data) == string)
        #expect(try JSONDecoder().decode(Value.self, from: data) == value)
    }

    @Test("Invalid decoded strings report dataCorrupted")
    func invalidCoding() throws {
        try checkInvalidCoding(TraceId.self, string: String(repeating: "0", count: 32))
        try checkInvalidCoding(SpanId.self, string: String(repeating: "0", count: 16))
        try checkInvalidCoding(TraceParent.self, string: Self.header + "-extra")
    }

    private func checkInvalidCoding<Value: Decodable>(_ type: Value.Type, string: String) throws {
        let data = try JSONEncoder().encode(string)
        do {
            _ = try JSONDecoder().decode(type, from: data)
            Issue.record("Expected dataCorrupted for invalid protocol data")
        } catch DecodingError.dataCorrupted {
            // Expected: decoding must enforce the same invariants as string parsing.
        }
    }

    @Test("Seed zero matches the SplitMix64 reference sequence")
    func referenceSequence() {
        var generator = SeededRandomNumberGenerator(seed: 0)
        #expect(generator.next() == 0xe220a8397b1dcdaf)
        #expect(generator.next() == 0x6e789e6aa1b965f4)
        #expect(generator.next() == 0x06c45d188009454f)
    }

    @Test("Seeds reproduce complete sequences", arguments: [UInt64(0), 42, UInt64.max])
    func seededSequence(_ seed: UInt64) {
        var first = SeededRandomNumberGenerator(seed: seed)
        var second = SeededRandomNumberGenerator(seed: seed)
        for _ in 0..<20 {
            #expect(TraceParent.random(using: &first) == TraceParent.random(using: &second))
        }
    }

    @Test("Sequential calls advance the generator and default flags are zero")
    func generationOrder() {
        var generator = SeededRandomNumberGenerator(seed: 0)
        let first = TraceParent.random(using: &generator)
        #expect(first.headerValue == "00-e220a8397b1dcdaf6e789e6aa1b965f4-06c45d188009454f-00")
        #expect(TraceParent.random(using: &generator) != first)
        var other = SeededRandomNumberGenerator(seed: 1)
        #expect(TraceParent.random(using: &other) != first)
    }

    @Test("All-zero identifiers are retried without rejecting partial zeros")
    func zeroRetry() {
        var generator = SequenceGenerator(values: [0, 0, 0, 1, 0, 2])
        let parent = TraceParent.random(using: &generator)
        #expect(parent.headerValue == "00-00000000000000000000000000000001-0000000000000002-00")
        #expect(generator.index == 6)
    }

    @Test("System random generation produces parseable values")
    func systemRandom() {
        for _ in 0..<20 {
            let parent = TraceParent.random()
            #expect(parent.flags == 0)
            #expect(TraceParent(headerValue: parent.headerValue) == parent)
            let trace = TraceId.random()
            #expect(TraceId(hexString: trace.hexString) == trace)
            let span = SpanId.random()
            #expect(SpanId(hexString: span.hexString) == span)
        }
    }
}

private struct SequenceGenerator: RandomNumberGenerator {
    let values: [UInt64]
    private(set) var index = 0

    mutating func next() -> UInt64 {
        precondition(index < values.count, "Unexpected extra random draw")
        defer { index += 1 }
        return values[index]
    }
}
