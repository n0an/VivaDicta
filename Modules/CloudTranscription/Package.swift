// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CloudTranscription",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CloudTranscription", targets: ["CloudTranscription"]),
        .library(name: "CloudTranscriptionMocks", targets: ["CloudTranscriptionMocks"]),
    ],
    dependencies: [
        .package(path: "../TranscriptionCore"),
        .package(path: "../Networking"),
        .package(path: "../TestUtilities"),
    ],
    targets: [
        .target(
            name: "CloudTranscription",
            dependencies: [
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "Networking", package: "Networking"),
            ]
        ),
        .target(
            name: "CloudTranscriptionMocks",
            dependencies: [
                "CloudTranscription",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "CloudTranscriptionTests",
            dependencies: [
                "CloudTranscription",
                "CloudTranscriptionMocks",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
//                .product(name: "Networking", package: "Networking"),
                .product(name: "NetworkingMocks", package: "Networking"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
