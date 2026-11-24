// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Telescopium",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Telescopium",
            targets: ["Telescopium"],
        ),
        .library(
            name: "TelescopiumOpenTelemetry",
            targets: ["TelescopiumOpenTelemetry"],
        ),
        .library(
            name: "TelescopiumDatadog",
            targets: ["TelescopiumDatadog"],
        ),
    ],
    traits: [
        .trait(name: "OpenTelemetry", description: "Enable the OpenTelemetry log exporter."),
        .trait(name: "Datadog", description: "Enable the Datadog log exporter."),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core", from: "2.5.0"),
        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", from: "3.21.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Telescopium",
            path: "Sources",
        ),
        .target(
            name: "TelescopiumOpenTelemetry",
            dependencies: [
                "Telescopium",
                .product(
                    name: "OpenTelemetryApi",
                    package: "opentelemetry-swift-core",
                    condition: .when(traits: ["OpenTelemetry"]),
                ),
            ],
            path: "Integrations/OpenTelemetry",
        ),
        .target(
            name: "TelescopiumDatadog",
            dependencies: [
                "Telescopium",
                .product(
                    name: "DatadogLogs",
                    package: "dd-sdk-ios",
                    condition: .when(traits: ["Datadog"]),
                ),
            ],
            path: "Integrations/Datadog",
        ),
        .testTarget(
            name: "TelescopiumTests",
            dependencies: ["Telescopium"],
        ),
        .testTarget(
            name: "ExporterIntegrationTests",
            dependencies: [
                "Telescopium",
                .target(name: "TelescopiumOpenTelemetry", condition: .when(traits: ["OpenTelemetry"])),
                .target(name: "TelescopiumDatadog", condition: .when(traits: ["Datadog"])),
                .product(
                    name: "OpenTelemetryApi",
                    package: "opentelemetry-swift-core",
                    condition: .when(traits: ["OpenTelemetry"]),
                ),
                .product(
                    name: "OpenTelemetrySdk",
                    package: "opentelemetry-swift-core",
                    condition: .when(traits: ["OpenTelemetry"]),
                ),
                .product(
                    name: "DatadogCore",
                    package: "dd-sdk-ios",
                    condition: .when(traits: ["Datadog"]),
                ),
                .product(
                    name: "DatadogLogs",
                    package: "dd-sdk-ios",
                    condition: .when(traits: ["Datadog"]),
                ),
            ],
        ),
    ],
)
