// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchBoard",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NotchBoard",
            path: "Sources/NotchBoard"
        )
    ]
)
