# Telescopium

A comprehensive Swift logging library built on Apple's unified logging system with performance measurement and log export capabilities.

## Features

- 🪵 **Structured Logging** - Built on `os.Logger` with automatic source context
- ⚡ **Performance Measurement** - Integrated `OSSignposter` for timing operations  
- 📊 **Log Export** - Forward structured records to a host-provided `LogExporter`
- 🎯 **Category-Based Loggers** - Create loggers per feature or component
- 🔒 **Privacy-Aware** - Automatic privacy protection for log messages
- 🧵 **Thread-Safe** - Safe for concurrent use across multiple threads
- 📱 **iOS 15+** - Modern iOS, macOS, tvOS, and watchOS support

## Requirements

- **iOS 15.0+** / **macOS 12.0+** / **tvOS 15.0+** / **watchOS 8.0+**
- Swift 5.9+
- Xcode 15.0+

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
It is a value only: tracing lifecycles, sampling policies, and network propagation remain the caller's responsibility.

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

### Setup Logger System (Optional)

```swift
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
    
    func redact(_ record: LogRecord) -> LogRecord {
        // Replace sensitive values in record.message/record.metadata.
        return record
    }
}

LoggerSystem.setup(
    exporters: [RemoteExporter()],
    redactors: [TokenRedactor()]
)
```

`setup` can be called again to replace the current exporters and redactors. Use `addExporter`, `addRedactor`, `removeAllExporters`, and `removeAllRedactors` for runtime changes.

### Redaction-Only Example

```swift
import Telescopium

struct NoOpExporter: LogExporter {
    func export(_ record: LogRecord) {}
}

struct MaskingRedactor: LogRedactor {
    let policy: RedactionPolicy = .always
    
    func redact(_ record: LogRecord) -> LogRecord {
        let masked: Metadata = record.metadata.mapValues { _ in "***" }
        return record.replacing(metadata: masked)
    }
}

LoggerSystem.setup(
    exporter: NoOpExporter(),
    redactors: [MaskingRedactor()]
)
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on Apple's excellent `os.Logger` and `OSSignposter` frameworks
- Inspired by the need for simple, powerful logging in iOS development
- Thanks to the Swift community for feedback and contributions
