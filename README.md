# Telescopium

[![CI](https://github.com/Weixi779/Telescopium/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Weixi779/Telescopium/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.2%2B-orange)
![Swift Package Manager](https://img.shields.io/badge/SwiftPM-supported-brightgreen)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

English | [简体中文](README_CN.md)

Structured logging and scoped tracing for Swift apps on Apple platforms. The package ships one library with zero third-party dependencies.

- Log to Apple's unified log by default, or forward structured records to an app-owned exporter.
- Trace synchronous and asynchronous work with `withSpan`, including nested requests and operations that throw.
- Record span intervals in Instruments with an `OSSignposter` configured by the app.

## Installation

Requires Swift tools 6.2 or later (Xcode 26+) and iOS 16+, macOS 13+, tvOS 16+, or watchOS 9+.

To use the 0.1.0 release once tagged, add the repository in Xcode under **Package Dependencies**. In a SwiftPM manifest, use the following package dependency.

```swift
.package(url: "https://github.com/Weixi779/Telescopium.git", from: "0.1.0")
```

To use a local checkout before the tag is available, use `.package(path: "../Telescopium")`. Both forms use the same target dependency.

```swift
.product(name: "Telescopium", package: "Telescopium")
```

## Quick start

Paste this into a Swift executable's `main.swift`. In an app, register the exporter once at startup and keep the logger alongside the feature that uses it.

```swift
import Foundation
import Telescopium

struct ConsoleSpanExporter: SpanExporter {
    func export(_ record: SpanRecord) {
        print(record.name, record.duration)
    }
}

Trace.register(tracer: TelescopiumTracer(exporter: ConsoleSpanExporter()))

let logger = Logger(category: "Playback")
let payload = Data(#"["Introduction", "Interview"]"#.utf8)

try withSpan("Decode chapters") { _ in
    let chapters = try JSONDecoder().decode([String].self, from: payload)
    logger.info("Loaded chapters", metadata: ["count": chapters.count])
}
```

The log goes to Apple's unified log. In Console, enable Info messages and filter by category `Playback`. The default exporter marks the text as private, so visibility depends on the system logging configuration. When the operation ends, the span exporter prints `Decode chapters` and its elapsed duration to standard output.

To attach the active span ID to each log record, register the app enricher from the [log correlation example](docs/logging.md#correlate-logs-with-the-current-span).

## Documentation

- [Logging](docs/logging.md) — Set category and metadata, enrich or redact a record, and register destinations.
- [Tracing](docs/tracing.md) — Trace requests and screen lifetimes, propagate W3C headers, and inspect intervals in Instruments.
- [Design decisions](docs/design.md) — Understand who owns configuration, span lifetime, and delivery.

## Development

With SwiftFormat and SwiftLint installed, run these checks from the package root.

```sh
swift test
swift test -c release
swiftformat --lint Package.swift Sources Tests
swiftlint lint --strict Package.swift Sources Tests
```

The [CI workflow](.github/workflows/ci.yml) pins the development tools and builds the library for iOS, tvOS, and watchOS in addition to running the tests on macOS.

## License

Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
