// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Telescopium",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Telescopium",
            targets: ["Telescopium"]
        ),
        .library(
            name: "TelescopiumOpenTelemetry",
            targets: ["TelescopiumOpenTelemetry"]
        ),
    ],
    traits: [
        .trait(name: "OpenTelemetry", description: "Enable the OpenTelemetry log exporter."),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core", from: "2.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Telescopium",
            path: "Sources"
        ),
        .target(
            name: "TelescopiumOpenTelemetry",
            dependencies: [
                "Telescopium",
                .product(
                    name: "OpenTelemetryApi",
                    package: "opentelemetry-swift-core",
                    condition: .when(traits: ["OpenTelemetry"])
                )
            ],
            path: "Integrations/OpenTelemetry"
        ),
        .testTarget(
            name: "TelescopiumTests",
            dependencies: ["Telescopium"]
        ),
    ]
)
