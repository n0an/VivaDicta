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
        // On-device LLM runtime that runs on the Apple Neural Engine (ANE), not
        // the Metal GPU. Because it never submits GPU command buffers, it can run
        // while the app is backgrounded (e.g. driven from the keyboard) - unlike
        // the GPU-bound LiteRT/MLX runtimes. Defaults to `.cpuAndNeuralEngine`.
        .package(url: "https://github.com/john-rocky/CoreML-LLM", from: "1.9.0"),
        // Tokenizer for the CoreML Qwen path (CoreMLLLM's Qwen3.5 generator takes
        // token ids, so we tokenize/detokenize here, like its example).
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LocalLLM",
            dependencies: [
                .product(name: "AICore", package: "AICore"),
                .product(name: "LiteRTFoundation", package: "swift-litert-lm"),
                .product(name: "CoreMLLLM", package: "CoreML-LLM"),
                .product(name: "Tokenizers", package: "swift-transformers"),
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
    ],
    // Swift 5 language mode: this module wraps concurrency-unfriendly native LLM
    // runtimes (CoreML-LLM's non-Sendable @Observable generators with nonisolated
    // async methods + a token callback). Building the module in v5 absorbs that
    // here; its public API (LiteRTGemmaVariant, CoreMLQwenVariant, the engine
    // protocols, etc.) is still declared Sendable, so the strict-v6 app consumes
    // it safely.
    swiftLanguageModes: [.v5]
)
