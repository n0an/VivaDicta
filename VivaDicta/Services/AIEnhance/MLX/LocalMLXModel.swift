//
//  LocalMLXModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Catalog of on-device MLX models (GPU, via mlx-swift-lm). Unlike the LiteRT /
//  Core ML runtimes (which live in the LocalLLM module), MLX is linked to the
//  app target for Metal-library bundling, so its types live here.
//
//  This type is plain Swift (no MLX import) so AIService / views can reference
//  it without pulling in MLXLLM. The manager maps `mlxRepo` -> ModelConfiguration.
//

import Foundation

/// An on-device MLX model offered in the AI Providers "Local" tab. Current small
/// 4-bit `mlx-community` builds suitable for iPhone (1-4B).
nonisolated enum LocalMLXModel: String, CaseIterable, Sendable {
    // Gemma first so the MLX cards sit next to the LiteRT Gemma cards for A/B.
    case gemma3n_E2B = "gemma-3n-e2b-mlx"
    case gemma3n_E4B = "gemma-3n-e4b-mlx"
    case qwen35_2B = "qwen3.5-2b-mlx"
    case qwen35_08B = "qwen3.5-0.8b-mlx"
    case phi4Mini = "phi-4-mini-mlx"
    case llama32_1B = "llama-3.2-1b-mlx"
    case llama32_3B = "llama-3.2-3b-mlx"
    case ministral3B = "ministral-3b-mlx"
    case falcon3_3B = "falcon3-3b-mlx"
    case granite33_2B = "granite-3.3-2b-mlx"
    case deepseekR1Qwen_1_5B = "deepseek-r1-qwen-1.5b-mlx"

    /// Unknown ids fall back to the recommended model.
    init(modelID: String) {
        self = LocalMLXModel(rawValue: modelID) ?? .qwen35_2B
    }

    var displayName: String {
        switch self {
        case .gemma3n_E2B: "Gemma 3n E2B"
        case .gemma3n_E4B: "Gemma 3n E4B"
        case .qwen35_2B: "Qwen3.5 2B"
        case .qwen35_08B: "Qwen3.5 0.8B"
        case .phi4Mini: "Phi-4 Mini"
        case .llama32_1B: "Llama 3.2 1B"
        case .llama32_3B: "Llama 3.2 3B"
        case .ministral3B: "Ministral 3B"
        case .falcon3_3B: "Falcon3 3B"
        case .granite33_2B: "Granite 3.3 2B"
        case .deepseekR1Qwen_1_5B: "DeepSeek R1 (Qwen 1.5B)"
        }
    }

    var subtitle: String {
        switch self {
        case .gemma3n_E2B: "Google's Gemma 3n - the LiteRT Gemma's weights, on MLX. Broad multilingual."
        case .gemma3n_E4B: "Larger Gemma 3n - the LiteRT E4B weights, on MLX. Broad multilingual."
        case .qwen35_2B: "Alibaba's Qwen3.5. Broad multilingual support."
        case .qwen35_08B: "Tiny, fastest option. Broad languages, but lower quality."
        case .phi4Mini: "Microsoft's Phi-4 Mini. Multilingual (~20+ languages)."
        case .llama32_1B: "Meta's tiny Llama 3.2. Best in English + 7 major languages."
        case .llama32_3B: "Meta's Llama 3.2. Best in English + 7 major languages."
        case .ministral3B: "Mistral's edge model. Strongest in European languages."
        case .falcon3_3B: "TII's Falcon3. Mainly English + a few European languages."
        case .granite33_2B: "IBM's Granite (Apache-2.0). ~12 languages, strong at following instructions."
        case .deepseekR1Qwen_1_5B: "DeepSeek R1 distill - a reasoning model; its thinking is hidden. Experimental, slower."
        }
    }

    /// HuggingFace repo id for the 4-bit MLX build.
    var mlxRepo: String {
        switch self {
        case .gemma3n_E2B: "mlx-community/gemma-3n-E2B-it-4bit"
        case .gemma3n_E4B: "mlx-community/gemma-3n-E4B-it-4bit"
        case .qwen35_2B: "mlx-community/Qwen3.5-2B-4bit"
        case .qwen35_08B: "mlx-community/Qwen3.5-0.8B-4bit"
        case .phi4Mini: "mlx-community/Phi-4-mini-instruct-4bit"
        case .llama32_1B: "mlx-community/Llama-3.2-1B-Instruct-4bit"
        case .llama32_3B: "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case .ministral3B: "mlx-community/Ministral-3-3B-Instruct-2512-4bit"
        case .falcon3_3B: "mlx-community/Falcon3-3B-Instruct-4bit"
        case .granite33_2B: "mlx-community/granite-3.3-2b-instruct-4bit"
        case .deepseekR1Qwen_1_5B: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"
        }
    }

    var approxDownloadDescription: String {
        switch self {
        case .gemma3n_E2B: "~2.6 GB"
        case .gemma3n_E4B: "~4.4 GB"
        case .qwen35_2B: "~1.3 GB"
        case .qwen35_08B: "~0.5 GB"
        case .phi4Mini: "~2.3 GB"
        case .llama32_1B: "~0.7 GB"
        case .llama32_3B: "~1.8 GB"
        case .ministral3B: "~1.8 GB"
        case .falcon3_3B: "~1.9 GB"
        case .granite33_2B: "~1.4 GB"
        case .deepseekR1Qwen_1_5B: "~1.0 GB"
        }
    }

    /// Asset name for the card icon (nil falls back to an SF symbol).
    var iconAsset: String? {
        switch self {
        case .gemma3n_E2B, .gemma3n_E4B: "gemma-color"
        case .qwen35_2B, .qwen35_08B: "qwen-color"
        case .phi4Mini: "microsoft-color"
        case .llama32_1B, .llama32_3B: "ollama" // reuse the llama mascot
        case .ministral3B: "mistral"
        case .falcon3_3B: "tii-color"
        case .granite33_2B: "ibm"
        case .deepseekR1Qwen_1_5B: "deepseek-color"
        }
    }

    /// Qwen chat templates honor `enable_thinking: false`; others ignore it.
    var supportsThinkingToggle: Bool {
        switch self {
        case .qwen35_2B, .qwen35_08B: true
        default: false
        }
    }

    var isRecommendedForThisDevice: Bool { self == .qwen35_2B }

    /// Where mlx-swift-lm's `defaultHubApi` materializes this repo:
    /// `<caches>/models/<repo>`.
    var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.cachesDirectory
        return caches.appending(path: "models").appending(path: mlxRepo)
    }

    /// True once the model is materialized on disk (dir + a config.json, so a
    /// partial download doesn't read as ready).
    var isDownloaded: Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: cacheDirectory.path(), isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return fm.fileExists(atPath: cacheDirectory.appending(path: "config.json").path())
    }

    /// On-disk size in bytes (0 when not downloaded).
    var downloadedBytes: Int64 {
        let fm = FileManager.default
        guard let e = fm.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in e {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}
