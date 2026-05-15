// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranscriptionCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TranscriptionCore", targets: ["TranscriptionCore"]),
    ],
    targets: [
        .target(name: "TranscriptionCore"),
        .testTarget(
            name: "TranscriptionCoreTests",
            dependencies: ["TranscriptionCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
