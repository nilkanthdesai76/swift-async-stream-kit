// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-async-stream-kit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "AsyncStreamKit",
            targets: ["AsyncStreamKit"]
        ),
    ],
    targets: [
        .target(
            name: "AsyncStreamKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AsyncStreamKitTests",
            dependencies: ["AsyncStreamKit"]
        ),
    ]
)
