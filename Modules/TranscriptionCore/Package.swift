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
        .library(name: "TranscriptionCoreMocks", targets: ["TranscriptionCoreMocks"]),
    ],
    targets: [
        .target(name: "TranscriptionCore"),
        .target(
            name: "TranscriptionCoreMocks",
            dependencies: ["TranscriptionCore"]
        ),
        .testTarget(
            name: "TranscriptionCoreTests",
            dependencies: ["TranscriptionCore", "TranscriptionCoreMocks"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
