// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pr-monitor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "pr-monitor",
            path: "Sources/pr-monitor"
        )
    ]
)
