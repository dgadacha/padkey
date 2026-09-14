// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PadKey",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PadKey",
            path: "Sources/PadKey",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
