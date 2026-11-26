# Telescopium

A Swift library for structured logging and performance measurement. Logs go to Apple's unified logging system by default.

## Features

- 🪵 **Structured Logging** - Capture each message, its metadata, and its source location in a `LogRecord`
- ⚡ **Performance Measurement** - Integrated `OSSignposter` for timing operations  
- 📊 **Log Export** - Forward structured records to a host-provided `LogExporter`
- 🎯 **Category-Based Loggers** - Create loggers per feature or component
- 🔒 **Privacy-Aware** - Apply redactors before export. The default OS exporter marks messages as private.
- 🧵 **Thread-Safe** - Safe for concurrent use across multiple threads
- 📱 **iOS 16+** - iOS, macOS, tvOS, and watchOS support

## Requirements

- **iOS 16.0+** / **macOS 13.0+** / **tvOS 16.0+** / **watchOS 9.0+**
- Swift tools 6.2+ (Xcode 26+)

## Installation

### Swift Package Manager

Add Telescopium to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Weixi779/Telescopium.git", from: "1.0.0")
]
```

## Trace Context Core

`TraceParent` generates, validates, and serializes the W3C Trace Context version `00` format.
The tracer manages the span lifecycle. The network layer chooses when to propagate the header.

```swift
import Telescopium

// Uses the system random source; version and flags default to 00.
let generated = TraceParent.random()
let header = generated.headerValue

// Strictly parses a complete lowercase version 00 header.
if let parsed = TraceParent(headerValue: "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01") {
    let explicit = TraceParent(
        traceId: parsed.traceId,
        spanId: parsed.spanId,
        flags: 0
    )
    print(explicit.headerValue)
}

// A fixed seed reproduces the sequence for tests and debugging.
var generator = SeededRandomNumberGenerator(seed: 42)
let reproducible = TraceParent.random(using: &generator)
let next = TraceParent.random(using: &generator)
```

`TraceParent`, `TraceId`, and `SpanId` conform to `Sendable`, `Hashable` (including `Equatable`), and `Codable`.
They encode as single strings and reject invalid strings during decoding.
Identifiers preserve leading zeros and reject all-zero values. Header parsing rejects unsupported versions,
uppercase hexadecimal, extra fields, and surrounding whitespace. Raw flag bytes are preserved.

The seeded generator uses SplitMix64 and is not cryptographically secure. Use the default system random
source for production identifiers; restarting a fixed seed repeats identifiers. A trace identifier consumes
two random words (high, then low), followed by one word for the span identifier; all-zero identifiers are retried.

## Quick Start

### Scoped Tracing

`withSpan` starts a span, makes its context available through `TraceScope.current`, and ends it when the operation returns or throws. Both synchronous and asynchronous operations use the same API.

```swift
let order = try await withSpan("Submit order") { span in
    span.setMetadata("checkout", forKey: "source")
    return try await orders.submit()
}
```

The built-in `TelescopiumTracer` creates a `TelescopiumSpan` for each operation. Its optional `onFinish` callback receives one `SpanRecord` on the caller's thread when the span first ends. The default tracer discards finished records.

```swift
Trace.register(tracer: TelescopiumTracer { record in
    print(record.name, record.duration)
})
```

An app can also register its own `Tracer`. Each new span uses the current registration and finishes with the tracer that created it.

### Basic Logging

```swift
import Telescopium

let logger = Logger()
logger.debug("App started")
logger.info("User logged in successfully") 
logger.warning("Playback timed out, retrying")
logger.error("Failed to load data", error: error)
logger.fault("Player entered the playing state without a current item")

// Instance interface (for custom categories)
let networkLogger = Logger(category: "Network")
networkLogger.info("API request started")

// Predefined categories
let featureLogger = Logger(category: "Network")
featureLogger.debug("Connection established")
```

### Structured Metadata

```swift
import Telescopium

let logger = Logger(
    category: "Auth",
    metadata: ["module": "Auth", "source": "app"]
)
logger.info(
    "Login succeeded",
    metadata: [
        "userId": "1234",
        "source": "web",
        "attempts": [["status": 200, "duration": 1.0]]
    ]
)
```

Each record inherits the logger's metadata. A call overrides matching top-level keys for that record, including entire objects and arrays. Pass Swift variables and existing dictionaries directly as `[String: Any]`. Use `NSNull()` or `MetadataValue.null` for an explicit null. The logger normalizes fields to `MetadataValue` before redaction and export. It skips unsupported values (including out-of-range unsigned integers and Decimal), keeps other fields and array elements in order, and reports the skipped location in debug builds.

### Register an Application Recorder

```swift
import Foundation
import Telescopium

/// Example exporter. Replace with your own OTLP/HTTP implementation.
final class RemoteExporter: LogExporter {
    func export(_ record: LogRecord) {
        // Forward to your remote logging backend.
    }
}

final class TokenRedactor: LogRedactor {
    let policy: RedactionPolicy = .when {
        ProcessInfo.processInfo.environment["ENV"] == "prod"
    }
    
    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.metadata.removeValue(forKey: "token")
        return result
    }
}

// App startup
Log.register(
    recorder: LogRecorder(
        redactors: [TokenRedactor()],
        exporters: [OSLogExporter(), RemoteExporter()]
    ),
    enrichers: [TraceCorrelationEnricher()]
)

// Playback
let logger = Logger(category: "Playback")
logger.info("Play tapped")
```

Each log call takes one snapshot of the application configuration. After merging metadata, the logger runs the registered enrichers synchronously in order. In this example, `TraceCorrelationEnricher` captures the current span in `record.traceParent`, so a recorder can queue the record and export it after the span ends. A logger created with `Logger(category: "Playback", recorder: recorder)` runs the same enrichers and sends the result to its own recorder. Other loggers use the recorder from the snapshot.

`LogRecorder` applies each enabled redactor once, in order, then sends the final record to every exporter. Both `LogEnricher` and `LogRedactor` inherit `LogRecordProcessor`. A host can also use `[any LogRecordProcessor]` directly and pass each returned record to the next processor.

With no registration, the application uses `LogRecorder()`, which exports to `OSLogExporter`. Register `LogRecorder(exporters: [])` to silence application logging, or register `LogRecorder()` to restore the default output.

### OpenTelemetry and Datadog

The base `Telescopium` product has no vendor target dependencies. Enable the package trait for each destination and link its library product in the consuming target. Both traits are off by default.

| Package trait | Library product | Dependency used by the exporter |
| --- | --- | --- |
| `OpenTelemetry` | `TelescopiumOpenTelemetry` | `OpenTelemetryApi` |
| `Datadog` | `TelescopiumDatadog` | `DatadogLogs` |

For example, an App package using a local checkout can select both integrations with:

```swift
// Package dependencies
.package(path: "../Telescopium", traits: ["OpenTelemetry", "Datadog"])

// App target dependencies
.product(name: "Telescopium", package: "Telescopium"),
.product(name: "TelescopiumOpenTelemetry", package: "Telescopium"),
.product(name: "TelescopiumDatadog", package: "Telescopium")
```

In a base-only consumer, SwiftPM 6.4 resolves no vendor packages. A Datadog-only consumer builds Datadog Logs and its internal module. SwiftPM also resolves dependencies declared upstream by Datadog, including OTel, even though it doesn't build those modules for logging. In Telescopium's checkout, run `swift test --traits OpenTelemetry,Datadog` to exercise the same Playback record through both SDKs.

```swift
import Telescopium
import TelescopiumOpenTelemetry
import TelescopiumDatadog
import DatadogCore
import DatadogLogs

// The App supplies its configured OTel LoggerProvider, Datadog configuration and consent.
let core = Datadog.initialize(with: datadogConfiguration, trackingConsent: consent)
Logs.enable(in: core)
let ddLogger = DatadogLogs.Logger.create(
    with: .init(name: "Telescopium", bundleWithTraceEnabled: false),
    in: core
)

Log.register(
    recorder: LogRecorder(
        redactors: [TokenRedactor()],
        exporters: [
            OSLogExporter(),
            OTelLogExporter(provider: provider),
            DatadogLogExporter(logger: ddLogger)
        ]
    ),
    enrichers: [TraceCorrelationEnricher()]
)

Telescopium.Logger(category: "Playback").warning("Retry playback", metadata: ["attempt": 2])
```

The OTel exporter uses the category as the instrumentation scope and preserves the record timestamp. Datadog uses the host logger's name and its SDK clock. The adapter also sends the category, subsystem, original epoch milliseconds, location and error snapshot in the `telescopium` attribute. The App owns SDK configuration, batching and upload.

When a record has a trace parent, the OTel exporter sets its native span context with the captured trace ID, span ID and flags. With no captured parent, the OTel SDK can use its active span at export time. Datadog receives the captured IDs as full lowercase hexadecimal strings in the top-level `trace_id` and `span_id` fields. The dedicated Datadog logger above disables automatic trace bundling so delayed logs keep their original association. [Datadog JSON correlation fields](https://docs.datadoghq.com/logs/log_configuration/pipelines/#trace-id-attribute)

Both exporters recursively map metadata after redaction. The table shows how to query the resulting fields.

| Metadata value | OpenTelemetry attribute | Datadog JSON |
| --- | --- | --- |
| Object / array | Attribute set / ordered array | Object / ordered array |
| Boolean / string / finite number | Corresponding typed value | Corresponding JSON value |
| Null | String `"null"`, including inside arrays | JSON `null` |
| Bytes | Base64 string | Base64 string |
| NaN / positive or negative infinity | Double | String `"NaN"`, `"Infinity"` or `"-Infinity"` |

The OTel Swift API has no native null or bytes case. These string encodings preserve array positions but are indistinguishable from matching user strings. On platforms with a 32-bit `Int`, OTel receives out-of-range integers as decimal strings. Datadog receives the full `Int64`. The adapters reserve their source and error fields when they add record context.

### Redaction-Only Example

```swift
import Telescopium

struct MaskingRedactor: LogRedactor {
    let policy: RedactionPolicy = .always
    
    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.metadata = record.metadata.mapValues { _ in "***" }
        return result
    }
}

// Send masked records to the default OS exporter.
Log.register(recorder: LogRecorder(redactors: [MaskingRedactor()]))
```

### Performance Measurement

```swift
import Telescopium

let logger = Logger()

// Measure synchronous operations
let result = logger.measure("database_query") {
    return database.fetchUsers()
}

// Measure asynchronous operations  
let data = await logger.measureAsync("api_request") {
    return await apiClient.getData()
}

// Manual timing for complex scenarios
let logger = Logger(category: "Performance")
let state = logger.startInterval("complex_operation")
// ... complex logic ...
logger.endInterval("complex_operation", state: state)

// Event markers
logger.event("checkpoint_reached", "Processing 50% complete")
```

## Log Levels

| Level   | Description | Persistence |
|---------|-------------|-------------|
| `debug` | Detailed debugging information | Not persisted in Release |
| `info`  | General informational messages | Persisted |
| `warning` | Unexpected or recoverable conditions | Persisted as `error` in Apple unified logging |
| `error` | Error conditions and failures | Persisted |
| `fault` | Potential bugs, such as a violated program invariant | Persisted |

## Categories

### Suggested Categories

```swift
// Use readable category strings for common use cases
let standardLogger = Logger()                        // General app logs
let networkLogger = Logger(category: "Network")      // Network operations
```

### Custom Categories

```swift
// Create custom categories for specific components
let databaseLogger = Logger(category: "Database")
let authLogger = Logger(category: "Authentication")
let cacheLogger = Logger(category: "Cache")
```

## Performance Analysis

Telescopium integrates with **Instruments** for visual performance analysis:

1. **Run your app with Instruments**
2. **Select the "Logging" template**
3. **Use signpost intervals** created by `measure()` methods
4. **Analyze timing data** in the Timeline view

Example Instruments view:
```
Timeline: Your App Process
├── Database Query     [■■■■░░░░░░] 45ms
├── API Request        [░░■■■■■■░░] 120ms  
└── Image Processing   [░░░░░■■■░░] 80ms
```

## Advanced Usage

### Async/Await Support

```swift
let logger = Logger()

// Perfect for measuring async operations
let user = await logger.measureAsync("user_login") {
    try await authService.login(credentials)
}

// Measure Task execution
await logger.measureAsync("background_processing") {
    await Task.detached {
        await processLargeDataSet()
    }.value
}
```

### Error Handling Best Practices

```swift
func performNetworkRequest() async {
    let logger = Logger(category: "Network")
    
    logger.info("Starting API request")
    
    do {
        let result = await logger.measureAsync("api_call") {
            try await apiClient.fetchData()
        }
        logger.info("API request completed successfully")
        return result
    } catch {
        logger.error("API request failed", error: error)
        throw error
    }
}
```

## Integration Examples

### Debug Menu Integration

```swift
#if DEBUG
struct DebugMenu: View {
    @State private var showingLogExport = false
    private let logger = Logger()
    
    var body: some View {
        List {
            Button("Export Logs") {
                showingLogExport = true
            }
            
            Button("Clear Cache") {
                logger.measure("cache_clear") {
                    CacheManager.shared.clearAll()
                }
            }
        }
        .sheet(isPresented: $showingLogExport) {
            LogExportView()
        }
    }
}
#endif
```

## Best Practices

### 1. Choose Appropriate Log Levels
```swift
// ✅ Good
let logger = Logger()
logger.debug("Entering function with parameters: \(params)")  // Development only
logger.info("User completed onboarding")                       // Important events  
logger.error("Network request failed", error: error)          // Actionable errors

// ❌ Avoid
logger.info("Loop iteration \(i)")                            // Too verbose
logger.error("User tapped button")                            // Not an error
```

### 2. Use Meaningful Categories
```swift
// ✅ Good
let authLogger = Logger(category: "Authentication") 
let paymentLogger = Logger(category: "Payment")

// ❌ Avoid  
let logger1 = Logger(category: "Stuff")
let logger2 = Logger(category: "Things")
```

### 3. Measure Performance Strategically
```swift
// ✅ Good - Measure significant operations
let logger = Logger(category: "Performance")
let result = logger.measure("image_processing") {
    return processImage(image)
}

// ❌ Avoid - Don't measure trivial operations
let sum = logger.measure("addition") { 
    return a + b  // Too fast to be meaningful
}
```

## Troubleshooting

### Common Issues

**Q: Performance measurements not showing in Instruments**  
- A: Make sure you're using the Logging template in Instruments
- A: Verify signposts are enabled in the Instruments settings

### Debug Tips

```swift
#if DEBUG
// Enable verbose logging in debug builds
Logger().debug("Detailed debug information here")

// Export logs for debugging
if ProcessInfo.processInfo.arguments.contains("--export-logs") {
    exportLogsForDebugging()
}
#endif
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Install the development tools with `brew install swiftformat swiftlint`. Run these commands from the package root as needed.

```sh
swiftformat . --lint    # Check formatting
swiftformat .           # Apply formatting
swiftlint lint --strict # Check for lint violations
```

## License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full terms and [NOTICE](NOTICE) for attribution.

## Acknowledgments

- Built on Apple's excellent `os.Logger` and `OSSignposter` frameworks
- Inspired by the need for simple, powerful logging in iOS development
- Thanks to the Swift community for feedback and contributions
