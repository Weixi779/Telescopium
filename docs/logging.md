# Logging

[Documentation](../README.md#documentation) · [简体中文](logging_CN.md)

A feature owns its `Logger`. The app chooses how its records are processed and where they go. With the default configuration a single call reaches Apple's unified log.

## Category, metadata and errors

```swift
import Telescopium

let playback = Logger(
    category: "Playback",
    metadata: ["module": "Playback", "request": ["attempt": 1, "cached": true]]
)
playback.info(
    "Retrying request",
    metadata: ["request": ["attempt": 2], "delays_ms": [100, 200]]
)
```

The record keeps `module = Playback`. The call replaces the entire `request` object with `["attempt": 2]`. A later call still sees the logger's original defaults. Arrays follow the same top-level replacement rule.

The subsystem comes from the main bundle identifier, falling back to `"app"`. The default category is `"Default"`. Each record captures the timestamp, severity, message, file ID, function, line and column at the call site. All five level methods accept an optional `error:`. Its `ErrorInfo` carries the concrete type name and message. An `NSError` or `CustomNSError` also supplies a domain and code. For an ordinary Swift error those two fields are `nil`.

### What arrives at the exporter

A logger accepts `[String: Any]` at initialization and at the call site. It converts the fields into `Metadata` (`[String: MetadataValue]`) before enrichment. Exporters can switch over the resulting values directly.

| Input | Stored value |
| --- | --- |
| `Bool`, string | `.bool`, `.string` |
| Integer representable as `Int64` | `.int` |
| `Float`, `Double` | `.double` |
| `Data` | `.bytes` |
| `NSNull()`, `MetadataValue.null` | `.null` |
| Array, string-keyed dictionary | `.array`, `.object`, with recursively converted children |

Conversion skips unsupported values, including `Decimal`, integers outside the `Int64` range, and cyclic references in Foundation containers. Arrays retain the relative order of the remaining elements. Debug builds log the path of a skipped value. For explicit conversion use `Metadata(converting:)` for a dictionary or `MetadataValue(converting:)` for a single value.

`LogRecord` is `Equatable` and `Codable`. Each encoded metadata node carries a type tag. For example, an integer encodes as `{"int":2}` and bytes as a Base64 string under the `bytes` tag. This lets a decoder recover the original type at any nesting depth. An exporter that needs a backend's JSON layout can map the cases to that layout.

## Filter before building a record

Set the recorder's threshold at app startup, for example `Log.register(recorder: LogRecorder(minimumLevel: .info))`. A `debug` call routed to this recorder returns before evaluating its message or per-call metadata. Interpolation and metadata expressions run once, synchronously on the caller, when the level is accepted. Keep required side effects outside those expressions. Compute a throwing or asynchronous argument before passing its value to the logger.

The built-in minimum is `.debug`. A recorder with an empty exporter list declines every level. Custom recorders can implement `isEnabled(for:)` to choose their levels and accept all levels by default. Apple's unified log configuration is checked separately by `OSLogExporter`.

## Correlate logs with the current span

Define an enricher in the app. It copies the active identity into the record while the logging call still has access to the task-local span context.

```swift
import Telescopium

struct CurrentSpanEnricher: LogEnricher {
    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.traceParent = record.traceParent ?? TraceScope.current?.traceParent
        return result
    }
}

Log.register(recorder: LogRecorder(), enrichers: [CurrentSpanEnricher()])
```

A log inside `withSpan` now carries that span's `TraceParent` even if the exporter reads the record later. A log outside a span keeps its existing parent, which is normally `nil`. This also works with the default context-only tracer. A structured exporter can read the IDs from the record.

## Redact and export

This app removes the top-level `token` field once, then sends the resulting record to two destinations. The console exporter prints only the category, severity, and trace ID. This configuration uses the enricher defined above.

```swift
struct RemoveToken: LogRedactor {
    let policy: RedactionPolicy = .always

    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.metadata.removeValue(forKey: "token")
        return result
    }
}

struct CorrelationExporter: LogExporter {
    func export(_ record: LogRecord) {
        let traceID = record.traceParent?.traceId.hexString ?? "none"
        print(record.category, record.level.rawValue, traceID)
    }
}

Log.register(
    recorder: LogRecorder(
        redactors: [RemoveToken()],
        exporters: [OSLogExporter(), CorrelationExporter()]
    ),
    enrichers: [CurrentSpanEnricher()]
)

withSpan("Refresh queue") { _ in
    Logger(category: "Playback").info("Queue refreshed")
}
```

Each `Log.register` call replaces the recorder and the ordered list of enrichers together. Each log call follows these steps.

1. The logger reads the app configuration once. It asks its explicitly bound recorder, or the current app recorder, whether it accepts the level.
2. For an accepted level, the logger builds the record, runs the captured enrichers in order on the caller's thread, and sends the resulting value to the selected recorder.
3. The built-in `LogRecorder` applies enabled redactors in order. A policy can be `.always`, `.never`, or `.when { … }`, evaluated for the record. Each exporter then receives the same final value synchronously, in configuration order. Different log calls can overlap.

Implement `LogExporter` to add a destination. Implement `LogRecording` if the app needs to own the whole recording step, including its redaction and delivery policy. Both enrichment and redaction use the public `LogRecordProcessor.process(_:)` contract, so a host can also compose its own chain. To silence the app's default destination, register `LogRecorder(exporters: [])`.

## Apple unified logging

| Record level | Apple log type |
| --- | --- |
| `debug` | `.debug` |
| `info` | `.info` |
| `warning`, `error` | `.error` |
| `fault` | `.fault` |

`OSLogExporter` checks whether the mapped level is enabled before formatting. Its private text contains the message, optional error type and description, and source location. Metadata and trace IDs remain available to structured exporters. Accepted records retain their original level in both Debug and Release. System configuration controls unified log visibility and retention.
