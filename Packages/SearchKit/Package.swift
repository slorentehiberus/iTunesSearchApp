// swift-tools-version: 6.2
import PackageDescription

// Layer dependencies, enforced by the compiler:
//
//   Presentation ──▶ Domain ◀── Data
//
// Domain depends on nothing. The app target is the only one that knows all three layers.
let package = Package(
    name: "SearchKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: layerSettings),
        .target(name: "Data", dependencies: ["Domain"], swiftSettings: layerSettings),
        .target(
            name: "Presentation",
            dependencies: ["Domain"],
            resources: [.process("Resources")],
            swiftSettings: layerSettings
        ),

        // Test helpers shared by the test targets of several layers.
        .target(
            name: "TestSupport",
            dependencies: ["Domain"],
            path: "Tests/TestSupport",
            swiftSettings: layerSettings
        ),

        .testTarget(name: "DataTests", dependencies: ["Data", "Domain", "TestSupport"], swiftSettings: layerSettings),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain", "TestSupport"], swiftSettings: layerSettings),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "TestSupport"], swiftSettings: layerSettings),
    ],
    swiftLanguageModes: [.v6]
)

/// Same language settings the app target used: `nonisolated` by default (the SwiftPM default),
/// approachable concurrency and explicit imports for every member.
let layerSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]
