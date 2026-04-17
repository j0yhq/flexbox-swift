// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlexLayout",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        // Public products — consumers add these as dependencies.
        .library(
            name: "FlexLayout",
            targets: ["FlexLayout"]
        ),
        .library(
            name: "CSSLayout",
            targets: ["CSSLayout"]
        ),
    ],
    targets: [
        // ── Library ────────────────────────────────────────────────────────────
        .target(
            name: "FlexLayout",
            path: "Sources/FlexLayout",
            swiftSettings: [
                // Treat all warnings as errors in release builds to keep the
                // public API surface clean.
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
            ]
        ),

        // ── CSSLayout — flexbox-only CSS → FlexLayout bridge ───────────────────
        .target(
            name: "CSSLayout",
            dependencies: ["FlexLayout"],
            path: "Sources/CSSLayout",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
            ]
        ),

        // ── Demo app (not a library product; local development only) ───────────
        .executableTarget(
            name: "FlexDemoApp",
            dependencies: ["FlexLayout"],
            path: "FlexDemoApp"
        ),

        // ── Tests ──────────────────────────────────────────────────────────────
        .testTarget(
            name: "FlexLayoutTests",
            dependencies: ["FlexLayout"],
            path: "Tests/FlexLayoutTests"
        ),
        .testTarget(
            name: "FlexDemoAppTests",
            dependencies: ["FlexDemoApp", "FlexLayout"],
            path: "Tests/FlexDemoAppTests"
        ),
        .testTarget(
            name: "CSSLayoutTests",
            dependencies: ["CSSLayout", "FlexLayout"],
            path: "Tests/CSSLayoutTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
