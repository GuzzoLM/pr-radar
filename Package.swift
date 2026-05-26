// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PRadar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PRadar",
            path: "Sources/pr-monitor"
        )
    ]
)
