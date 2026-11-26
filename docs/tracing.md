# Tracing

[Documentation](../README.md#documentation) · [简体中文](tracing_CN.md)

A span represents one operation. The tracer that starts it owns its end. `TraceScope.current` carries the innermost span's identity through synchronous calls and across suspension points.

## Trace a pair of requests

The app's network client supplies `send`. One purchase produces three spans. The two client spans share the purchase as their parent and run in sequence. Each request returns to the purchase scope before the next starts.

```swift
import Telescopium

func confirmPurchase(send: (String) async throws -> Void) async throws {
    try await withSpan("Confirm purchase") { _ in
        try await withSpan("POST /orders", ofKind: .client) { span in
            span.setMetadata("POST", forKey: "http.method")
            try await send("/orders")
            span.addEvent(SpanEvent("Order accepted"))
        }
        try await withSpan("POST /payments", ofKind: .client) { _ in
            try await send("/payments")
        }
    }
}
```

If the order request throws, both open spans end with that error, the caller's previous context is restored, and the payment request is skipped. Synchronous work uses the same `withSpan` spelling. Use `.internal` (the default) for in-process work, `.client` and `.server` for the two sides of a request, and `.producer` and `.consumer` for queued work.

## Choose what to record

The default `TelescopiumTracer()` gives each span a context so child operations and logs can carry its identity. To collect timing, events, metadata, and errors, supply a `SpanExporter`. Register the tracer at startup for global `withSpan` calls. A component with an injected tracer can call `tracer.withSpan` directly.

```swift
struct TimingExporter: SpanExporter {
    func export(_ record: SpanRecord) {
        print(record.name, record.duration, record.events.map(\.name))
    }
}

let tracer = TelescopiumTracer(exporter: TimingExporter())
Trace.register(tracer: tracer)
```

The first end delivers one completed `SpanRecord` synchronously on the calling thread. Different spans can finish concurrently. Use `duration` for elapsed time and `startTime` / `endTime` for wall-clock correlation. The record includes the operation name and kind, context, optional parent span ID, ordered events, metadata, and optional `ErrorInfo`. Both the record and its events support `Codable` and `Equatable`.

If a backend must create its own live span, implement `Tracer` and register that implementation instead. Its `startSpan(_:ofKind:parent:)` receives the parent from the scope. Return a handle conforming to `Span` that exposes the new context and forwards `setMetadata` and `addEvent`. Its `endSpan(_:throwing:)` receives that same concrete handle and the original error, if any. See the [design decision](design.md#who-creates-the-live-span).

## Keep a span across callbacks

A screen opens in one callback and closes in another. Start its span explicitly, keep it on the screen owner, and bind it as current only while running work for that screen. This example keeps the tracer used for child requests as well.

```swift
final class OrderDetailsScreen {
    private let tracer: any Tracer
    private let page: any Span
    let close: () -> Void

    init(tracer: some Tracer) {
        let page = tracer.startSpan("Order details", ofKind: .internal, parent: TraceScope.current)
        self.tracer = tracer
        self.page = page
        close = { tracer.endSpan(page, throwing: nil) }
    }

    func refresh(load: () async throws -> Void) async throws {
        try await page.withCurrent {
            try await tracer.withSpan("GET /orders/{id}", ofKind: .client) { _ in
                try await load()
            }
        }
    }
}
```

Create the owner when the screen opens and call `close()` when that screen lifetime ends. `page.withCurrent` restores the surrounding context on return or throw. The page can parent later refreshes. The initializer captures the concrete tracer/span pair in the closing operation, so the screen can accept an injected or signposted tracer without becoming generic itself.

## Carry context across a network boundary

`TraceParent` holds a trace ID, the sending span's ID, and flags. The sender's span becomes the receiver's parent. `TraceState` carries ordered vendor entries. `SpanContext` combines both values with `isRemote`, which identifies a context extracted from another process. A local child inherits the trace ID, flags, and state, gets a fresh span ID, and has `isRemote == false`.

The network layer chooses which destinations receive the headers. Call the following helper inside the outgoing client span for a request intended to propagate its context.

```swift
import Foundation

func attachTraceContext(to request: inout URLRequest) {
    guard let context = TraceScope.current else { return }
    request.setValue(context.traceParent.headerValue, forHTTPHeaderField: "traceparent")
    let state = context.traceState.headerValue
    request.setValue(state.isEmpty ? nil : state, forHTTPHeaderField: "tracestate")
}
```

At the receiving boundary, parse the headers and bind the remote context before starting the server span. Start a fresh root on an invalid or missing parent. A valid parent can still be used when vendor state is missing or malformed.

```swift
func handleRequest(
    parentHeader: String?,
    stateHeader: String?,
    handle: () throws -> Void
) rethrows {
    let parent = parentHeader.flatMap(TraceParent.init(headerValue:)).map { traceParent in
        SpanContext(
            traceParent: traceParent,
            traceState: stateHeader.flatMap(TraceState.init(headerValue:)) ?? TraceState(),
            isRemote: true
        )
    }
    try TraceScope.$current.withValue(parent) {
        try withSpan("Handle order", ofKind: .server) { _ in try handle() }
    }
}
```

Telescopium parses the 55-byte lowercase version `00` form, for example `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`. The trace ID has 32 hex digits and the span ID has 16. Leading zeros are preserved. An all-zero ID, unsupported version, or surrounding whitespace makes parsing fail. The final byte preserves all flags. The built-in tracer starts roots with the sampled bit clear and propagates the parent's flags to children. Its exporter configuration controls local recording. [W3C Trace Context](https://www.w3.org/TR/trace-context/)

Use `TraceParent.random()` for a new identity, or pass a `SeededRandomNumberGenerator` to `random(using:)` for reproducible fixtures. The seeded generator uses SplitMix64 and repeats the sequence for the same seed. `TraceParent`, `TraceId`, `SpanId`, and `TraceState` encode as single strings. To update vendor state, `settingValue(_:forKey:)` returns a new value with the entry first, or `nil` for an invalid entry. Adding a new key at the 32-entry limit evicts the last one.

## Inspect durations in Instruments

Decorate the tracer at app startup and select the subsystem and category there. This example combines span export and signposts. Use `TelescopiumTracer().signposted(by: signposter)` if Instruments is the only destination.

```swift
import os

let signposter = OSSignposter(
    subsystem: "com.example.shop",
    category: .pointsOfInterest
)
Trace.register(tracer: tracer.signposted(by: signposter))
```

Record with the `os_signpost` instrument and look for intervals named `Span` under the configured subsystem and category. The operation name appears in the public interval message, so use stable names such as `GET /orders/{id}`. The decorator emits an interval when the signposter is enabled at span start. `SpanEvent` values go to the underlying span. To mark an instant separately in Instruments, the app can call `signposter.emitEvent("Checkpoint")`.
