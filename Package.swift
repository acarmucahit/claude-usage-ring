// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeUsageRing",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClaudeUsageRingCore"),
        .executableTarget(
            name: "ClaudeUsageRing",
            dependencies: ["ClaudeUsageRingCore"]
        ),
        .testTarget(
            name: "ClaudeUsageRingCoreTests",
            dependencies: ["ClaudeUsageRingCore"]
        ),
    ]
)
