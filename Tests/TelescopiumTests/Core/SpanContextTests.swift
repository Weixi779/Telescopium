//
//  SpanContextTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/23.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Testing
import Telescopium

struct SpanContextTests {
    @Test("A local span starts with empty vendor state")
    func localDefaults() {
        let parent = TraceParent.random()
        let context = SpanContext(traceParent: parent)
        #expect(context.traceParent == parent)
        #expect(context.traceState.entries.isEmpty)
        #expect(!context.isRemote)
    }

    @Test("The extracted identity is remote and its local child has a distinct span ID")
    func remoteParentAndLocalChild() throws {
        let header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        let parent = try #require(TraceParent(headerValue: header))
        let state = try #require(TraceState(headerValue: "rojo=123,congo=456"))
        let remote = SpanContext(traceParent: parent, traceState: state, isRemote: true)

        let childID = try #require(SpanId(hexString: "0000000000000001"))
        let child = SpanContext(
            traceParent: TraceParent(traceId: parent.traceId, spanId: childID, flags: parent.flags),
            traceState: remote.traceState
        )
        #expect(remote.isRemote)
        #expect(!child.isRemote)
        #expect(child.traceParent.traceId == remote.traceParent.traceId)
        #expect(child.traceParent.spanId != remote.traceParent.spanId)
        #expect(child.traceState == remote.traceState)
        #expect(remote.traceParent.headerValue == header)

        let data = try JSONEncoder().encode(remote)
        #expect(try JSONDecoder().decode(SpanContext.self, from: data) == remote)
    }
}
