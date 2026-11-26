// swift-tools-version: 6.2
import PackageDescription

// Layer dependencies, enforced by the compiler:
//
//   Presentation ──▶ Domain ◀── Data
//
// Domain depends on nothing. The app target is the only one that knows all three layers.
// The unit tests live in the Xcode project (iTunesSearchAppTests), which imports the modules with @testable.
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
