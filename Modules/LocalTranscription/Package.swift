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
        .library(name: "LocalTranscriptionMocks", targets: ["LocalTranscriptionMocks"]),
    ],
    dependencies: [
        .package(path: "../TranscriptionCore"),
        .package(path: "../TestUtilities"),
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", branch: "main"),
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.17.5"),
    ],
    targets: [
        .target(
            name: "LocalTranscription",
            dependencies: [
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "SpeakerKit", package: "argmax-oss-swift"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .target(
            name: "LocalTranscriptionMocks",
            dependencies: [
                "LocalTranscription",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
        .testTarget(
            name: "LocalTranscriptionTests",
            dependencies: [
                "LocalTranscription",
                "LocalTranscriptionMocks",
                .product(name: "TranscriptionCore", package: "TranscriptionCore"),
                .product(name: "TestUtilities", package: "TestUtilities"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
