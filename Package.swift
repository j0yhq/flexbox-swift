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
        .library(
            name: "FlexLayout",
            targets: ["FlexLayout"]
        ),
    ],
    targets: [
        // ── Library ────────────────────────────────────────────────────────────
        .target(
            name: "FlexLayout",
            path: "Sources/FlexLayout"
            // NOTE: `-warnings-as-errors` was removed. As an `.unsafeFlags`
            // entry it (a) conflicts with the `-suppress-warnings` Xcode injects
            // when this package is built as a dependency during an XCFramework
            // archive, and (b) blocks version-pinned SwiftPM consumers (unsafe
            // flags force revision/branch pins). Enforce warnings in CI instead.
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
    ]
)
