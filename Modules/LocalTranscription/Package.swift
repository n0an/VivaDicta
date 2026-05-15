// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalTranscription",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LocalTranscription", targets: ["LocalTranscription"]),
    ],
    targets: [
        .target(name: "LocalTranscription"),
        .testTarget(
            name: "LocalTranscriptionTests",
            dependencies: ["LocalTranscription"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
