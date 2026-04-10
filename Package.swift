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
        .library(name: "FlexLayout", targets: ["FlexLayout"]),
        .executable(name: "FlexDemoApp", targets: ["FlexDemoApp"]),
    ],
    targets: [
        .target(
            name: "FlexLayout",
            path: "Sources/FlexLayout"
        ),
        .executableTarget(
            name: "FlexDemoApp",
            dependencies: ["FlexLayout"],
            path: "FlexDemoApp"
        ),
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
    ]
)
