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
        // On-device LLM runtimes - owned here so the heavy, iOS-only native
        // frameworks are firewalled into this module instead of linked directly
        // by the app target (mirrors how LocalTranscription owns WhisperKit).
        .package(url: "https://github.com/n0an/swift-litert-lm.git", branch: "main"),
        // MLX (GPU) runtime - pinned to the same revision the app target used
        // before MLX was consolidated into this module.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "edd42fcd947eea0b19665248acf2975a28ddf58b"),
    ],
    targets: [
        .target(
            name: "LocalLLM",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
                .product(name: "LiteRTFoundation", package: "swift-litert-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
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
