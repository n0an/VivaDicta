// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranscriptionKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TranscriptionKit", targets: ["TranscriptionKit"]),
    ],
    dependencies: [
        .package(path: "../TranscriptionCore"),
        .package(path: "../CloudTranscription"),
        .package(path: "../LocalTranscription"),
    ],
    targets: [
        .target(
            name: "TranscriptionKit",
            dependencies: [
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "CloudTranscription", package: "CloudTranscription"),
                .product(name: "LocalTranscription", package: "LocalTranscription"),
            ]
        ),
        .testTarget(
            name: "TranscriptionKitTests",
            dependencies: ["TranscriptionKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
