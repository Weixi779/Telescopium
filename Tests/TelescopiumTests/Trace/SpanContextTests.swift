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
    @Test("Each root starts an independent local trace with empty vendor state")
    func independentRoots() {
        let root = SpanContext.root()
        let other = SpanContext.root()
        #expect(root.traceParent.traceId != other.traceParent.traceId)
        #expect(root.traceParent.flags == 0)
        #expect(root.traceState.entries.isEmpty)
        #expect(!root.isRemote)
    }

    @Test("The extracted identity is remote and its local child has a distinct span ID")
    func remoteParentAndLocalChild() throws {
        let header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        let parent = try #require(TraceParent(headerValue: header))
        let state = try #require(TraceState(headerValue: "rojo=123,congo=456"))
        let remote = SpanContext(traceParent: parent, traceState: state, isRemote: true)

        let child = remote.child()
        #expect(remote.isRemote)
        #expect(!child.isRemote)
        #expect(child.traceParent.traceId == remote.traceParent.traceId)
        #expect(child.traceParent.spanId != remote.traceParent.spanId)
        #expect(child.traceParent.flags == parent.flags)
        #expect(child.traceState == remote.traceState)
        #expect(remote.traceParent.headerValue == header)

        let data = try JSONEncoder().encode(remote)
        #expect(try JSONDecoder().decode(SpanContext.self, from: data) == remote)
    }
}
