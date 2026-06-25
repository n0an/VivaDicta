// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalLLM",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "LocalLLM", targets: ["LocalLLM"]),
        .library(name: "LocalLLMMocks", targets: ["LocalLLMMocks"]),
    ],
    dependencies: [
        .package(path: "../AICore"),
        // On-device LLM runtime - owned here so the heavy, iOS-only native
        // framework is firewalled into this module instead of linked directly
        // by the app target (mirrors how LocalTranscription owns WhisperKit).
        .package(url: "https://github.com/n0an/swift-litert-lm.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "LocalLLM",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
                .product(name: "LiteRTFoundation", package: "swift-litert-lm"),
            ]
        ),
        .target(
            name: "LocalLLMMocks",
            dependencies: ["LocalLLM"]
        ),
        .testTarget(
            name: "LocalLLMTests",
            dependencies: ["LocalLLM", "LocalLLMMocks"]
        ),
    ]
)
