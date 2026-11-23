//
//  TraceStateTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/23.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct TraceStateTests {
    @Test("A header retains vendor order and opaque values through Codable")
    func orderedRoundTrip() throws {
        let state = try #require(TraceState(headerValue: " \t9@rojo= leading space , , congo=x:y/z\t"))
        #expect(state.entries.map(\.key) == ["9@rojo", "congo"])
        #expect(state["9@rojo"] == " leading space")
        #expect(state["other"] == nil)
        #expect(state.headerValue == "9@rojo= leading space,congo=x:y/z")
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(String.self, from: data) == state.headerValue)
        #expect(try JSONDecoder().decode(TraceState.self, from: data) == state)
    }

    @Test("Empty list members produce empty state", arguments: ["", " \t", ",,", " , \t,"])
    func emptyHeaders(_ header: String) {
        #expect(TraceState(headerValue: header) == TraceState())
        #expect(TraceState().headerValue.isEmpty)
    }

    @Test(
        "Invalid headers fail validation through both initializers",
        arguments: [
            "vendor", "vendor=", "=value", "a=1,a=2", "vendor =value",
            "A=1", "1vendor=1", "a@@b=1", "a@0=1", "a.=1",
            "a=x=y", "a=x\ty", "a=\nvalue", "a=å",
            String(repeating: "a", count: 257) + "=1",
            String(repeating: "a", count: 242) + "@x=1",
            "a@" + String(repeating: "x", count: 15) + "=1",
            "a=" + String(repeating: "x", count: 257)
        ]
    )
    func invalidHeader(_ header: String) throws {
        #expect(TraceState(headerValue: header) == nil)
        let data = try JSONEncoder().encode(header)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TraceState.self, from: data)
        }
    }

    @Test("Simple and multi-tenant keys accept their full W3C lengths")
    func entryLimits() throws {
        let longestValue = String(repeating: "x", count: 256)
        let simpleKey = String(repeating: "a", count: 256)
        let tenantKey = String(repeating: "1", count: 241) + "@" + String(repeating: "b", count: 14)
        let first = try #require(TraceState.Entry(key: simpleKey, value: longestValue))
        let second = try #require(TraceState.Entry(key: tenantKey, value: longestValue))
        let state = try #require(TraceState(entries: [first, second]))
        #expect(TraceState(headerValue: state.headerValue) == state)
        #expect(TraceState(entries: [first, first]) == nil)
        #expect(TraceState.Entry(key: "vendor", value: "trailing ") == nil)
        #expect(TraceState.Entry(key: "vendor", value: "x,y") == nil)
    }

    @Test("A header accepts 32 members and rejects a 33rd")
    func memberLimit() throws {
        let header = (1...32).map { "v\($0)=x" }.joined(separator: ",")
        let state = try #require(TraceState(headerValue: header))
        #expect(state.entries.count == 32)
        #expect(TraceState(headerValue: header + ",extra=y") == nil)
        let entry = try #require(TraceState.Entry(key: "extra", value: "y"))
        #expect(TraceState(entries: state.entries + [entry]) == nil)
    }
}
