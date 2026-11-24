//
//  WithSpanTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

import Testing
@testable import Telescopium

private enum DraftError: Error { case invalid }

struct WithSpanTests {
    @Test("Synchronous children share a trace and restore the parent between siblings")
    func synchronousNesting() throws {
        let root = try withSpan("Save draft") { span in
            let root = try #require(span as? SpanRecord)
            #expect(root.parentSpanId == nil)
            #expect(TraceScope.current == root.context)
            let first = try withSpan("Prepare") { try #require($0 as? SpanRecord) }
            #expect(TraceScope.current == root.context)
            let second = try withSpan("Write") { try #require($0 as? SpanRecord) }
            #expect(first.context.traceParent.spanId != second.context.traceParent.spanId)
            for child in [first, second] {
                #expect(child.parentSpanId == root.context.traceParent.spanId)
                #expect(child.context.traceParent.traceId == root.context.traceParent.traceId)
                #expect(child.state.endTime != nil)
            }
            #expect(root.state.endTime == nil)
            span.setMetadata(3, forKey: "bytes")
            return root
        }
        #expect(TraceScope.current == nil)
        #expect(root.state.endTime != nil)
        root.setMetadata(9, forKey: "bytes")
        #expect(root.state.metadata["bytes"] == 3)
    }

    @Test("A sync failure freezes the record and restores the previous context")
    func syncThrow() throws {
        var failed: SpanRecord?
        #expect(throws: DraftError.invalid) {
            try withSpan("Validate") { span in
                failed = try #require(span as? SpanRecord)
                throw DraftError.invalid
            }
        }
        let record = try #require(failed)
        #expect(record.state.endTime != nil)
        #expect(record.state.error as? DraftError == .invalid)
        #expect(TraceScope.current == nil)
    }

    @Test("A locally created child inherits flags and vendor state from a bound remote context")
    func boundParent() throws {
        let header = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        let parent = try #require(TraceParent(headerValue: header))
        let state = try #require(TraceState(headerValue: "acme=sample"))
        let remote = SpanContext(traceParent: parent, traceState: state, isRemote: true)
        try TraceScope.$current.withValue(remote) {
            let child = try withSpan("Import", ofKind: .consumer) { try #require($0 as? SpanRecord) }
            #expect(child.name == "Import")
            #expect(child.kind == .consumer)
            #expect(child.parentSpanId == parent.spanId)
            #expect(child.context.traceParent.traceId == parent.traceId)
            #expect(child.context.traceParent.flags == parent.flags)
            #expect(child.context.traceState == state)
            #expect(!child.context.isRemote)
            #expect(TraceScope.current == remote)
        }
    }

    @Test("Sibling tasks keep their own current span across suspension")
    func concurrentChildren() async {
        await withSpan("Import") { root in
            await withTaskGroup(of: SpanContext.self) { group in
                for name in ["First", "Second"] {
                    group.addTask {
                        #expect(TraceScope.current == root.context)
                        let child = await withSpan(name) { span in
                            await Task.yield()
                            #expect(TraceScope.current == span.context)
                            return span.context
                        }
                        #expect(TraceScope.current == root.context)
                        return child
                    }
                }
                var children: Set<SpanId> = []
                for await child in group {
                    #expect(child.traceParent.traceId == root.context.traceParent.traceId)
                    children.insert(child.traceParent.spanId)
                }
                #expect(children.count == 2)
                #expect(TraceScope.current == root.context)
            }
        }
        #expect(TraceScope.current == nil)
    }

    @Test("An async throw restores the caller's context and preserves actor-local results")
    @MainActor
    func asyncThrow() async throws {
        final class Draft { var edits = 0 }
        let draft = Draft()
        let result = try await withSpan("Edit") { root in
            let current = withSpan("Read") { $0.context }
            #expect(current.traceParent.traceId == root.context.traceParent.traceId)
            var failed: SpanRecord?
            do {
                try await withSpan("Commit") { span in
                    await Task.yield()
                    MainActor.assertIsolated()
                    draft.edits += 1
                    failed = try #require(span as? SpanRecord)
                    throw DraftError.invalid
                }
                Issue.record("Expected the edit to throw")
            } catch DraftError.invalid {
                #expect(TraceScope.current == root.context)
            }
            let record = try #require(failed)
            #expect(record.state.endTime != nil)
            #expect(record.state.error as? DraftError == .invalid)
            return draft
        }
        #expect(result === draft)
        #expect(result.edits == 1)
        #expect(TraceScope.current == nil)
    }
}
