//
//  CoreMLQwenModelManager.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.27
//
//  Owns the on-device Qwen3.5 model (CoreML-LLM) - the CoreML counterpart to
//  LiteRTModelManager / LocalMLXModelManager. Unlike those two, CoreML-LLM runs
//  inference on the Apple Neural Engine (ANE), NOT the Metal GPU. iOS forbids GPU
//  command-buffer submission from a backgrounded app (that is why LiteRT/MLX
//  hang/crash when driven from the keyboard), but ANE work is permitted in the
//  background - so this runtime is the one on-device LLM that works from the
//  keyboard. We pin `.cpuAndNeuralEngine` explicitly so it can never fall back to
//  the GPU and lose that property.
//
//  Qwen3.5 uses the low-level `Qwen35MLKVGenerator` (token-ids in/out), so this
//  also owns the tokenizer (swift-transformers) and the download (CoreML-LLM's
//  `ModelDownloader`, whose built-in ModelInfo already points at the
//  `mlboydaisuke/*` HuggingFace repos).
//
//  CoreMLLLM's generator + tokenizer are non-Sendable @Observable classes with
//  nonisolated async methods; the module's Swift 5 language mode absorbs that,
//  and this manager's public surface (variant + engine protocol) stays Sendable.
//

import Foundation
import os

#if canImport(CoreMLLLM)
@preconcurrency import CoreMLLLM
@preconcurrency import Tokenizers
import CoreML
#endif

/// The on-device Qwen variants the app can run via CoreML (ANE). Raw values match
/// the CoreML entries in `AIProvider.local`'s model identifiers - suffixed
/// `-coreml` to disambiguate from the MLX Qwen models (`qwen3.5-2b-mlx`).
public nonisolated enum CoreMLQwenVariant: String, CaseIterable, Sendable {
    case qwen2B = "qwen3.5-2b-coreml"
    case qwen08B = "qwen3.5-0.8b-coreml"

    public init(modelID: String) {
        self = CoreMLQwenVariant(rawValue: modelID) ?? .qwen2B
    }

    public var displayName: String {
        switch self {
        case .qwen2B: "Qwen3.5 2B"
        case .qwen08B: "Qwen3.5 0.8B"
        }
    }

    /// Short description for the settings cards. Emphasizes the keyboard-friendly
    /// ANE story (the reason to pick CoreML over the faster GPU runtimes).
    public var subtitle: String {
        switch self {
        case .qwen2B: "Runs on the Neural Engine, so it also works from the keyboard. Higher quality, very low memory. Slower than GPU models."
        case .qwen08B: "Runs on the Neural Engine, so it also works from the keyboard. Smallest and fastest to download; lower quality than 2B."
        }
    }

    /// Approximate download size, shown before downloading.
    public var approxDownloadDescription: String {
        switch self {
        case .qwen2B: "~2.8 GB"
        case .qwen08B: "~1.2 GB"
        }
    }

    /// HuggingFace tokenizer repo (fetched at runtime by swift-transformers).
    var tokenizerId: String {
        switch self {
        case .qwen2B: "Qwen/Qwen3.5-2B"
        case .qwen08B: "Qwen/Qwen3.5-0.8B"
        }
    }

    #if canImport(CoreMLLLM)
    /// CoreML-LLM's built-in ModelInfo (its `downloadURL` already points at the
    /// `mlboydaisuke/qwen3.5-*-CoreML` HuggingFace repos).
    var modelInfo: ModelDownloader.ModelInfo {
        switch self {
        case .qwen2B: .qwen35_2b
        case .qwen08B: .qwen35_08b
        }
    }
    #endif

    /// Whether the model is downloaded (synchronous, for the picker/cards filter).
    public var isDownloaded: Bool {
        #if canImport(CoreMLLLM)
        ModelDownloader.shared.isDownloaded(modelInfo)
        #else
        false
        #endif
    }

    /// 2B is the recommended pick - both run comfortably on the ANE (~200 MB),
    /// so prefer the higher-quality one.
    public var isRecommendedForThisDevice: Bool { self == .qwen2B }
}

/// Model-lifecycle surface the Qwen settings view model depends on (parallel to
/// `LocalModelEngine` for Gemma). Seamed so the view model can be unit-tested
/// against a mock instead of the real downloader/ANE runtime.
public protocol CoreMLQwenEngine: Sendable {
    func ensureLoaded(variant: CoreMLQwenVariant, onDownloadProgress: (@Sendable (Double) -> Void)?) async throws
    func isDownloaded(_ variant: CoreMLQwenVariant) async -> Bool
    func downloadedBytes(_ variant: CoreMLQwenVariant) async -> Int64
    func deleteModel(_ variant: CoreMLQwenVariant) async throws
}

public actor CoreMLQwenModelManager: CoreMLQwenEngine {
    public static let shared = CoreMLQwenModelManager()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "CoreMLQwen")

    #if canImport(CoreMLLLM)
    private let downloader = ModelDownloader.shared
    private var generator: Qwen35MLKVGenerator?
    private var tokenizer: (any Tokenizer)?
    #endif

    private(set) var loadedVariant: CoreMLQwenVariant?
    private var isGenerating = false
    private var isLoading = false

    private init() {}

    /// Download (first launch only) + load the requested variant. Download-allowed
    /// path - call only from the Settings download action; generation uses
    /// `loadForGeneration`, which never downloads.
    public func ensureLoaded(variant: CoreMLQwenVariant = .qwen2B, onDownloadProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        #if canImport(CoreMLLLM)
        if generator != nil, loadedVariant == variant { return }
        guard !isLoading, !isGenerating else { throw CoreMLQwenError.busy }
        isLoading = true
        defer { isLoading = false }
        generator = nil
        tokenizer = nil
        loadedVariant = nil

        let info = variant.modelInfo
        let folder: URL
        if downloader.isDownloaded(info), let url = downloader.localModelURL(for: info) {
            // load() wants the folder CONTAINING the chunks subdir; localModelURL
            // points one level in (matches CoreML-LLM's own example).
            folder = url.deletingLastPathComponent()
        } else {
            // The card shows an indeterminate "Downloading..." (multi-file model
            // progress is non-linear and reads as stuck), so 0 -> 1 is enough.
            onDownloadProgress?(0)
            let url = try await downloader.download(info)
            onDownloadProgress?(1)
            folder = url.deletingLastPathComponent()
        }

        let tok = try await AutoTokenizer.from(pretrained: variant.tokenizerId)
        let cfg: Qwen35MLKVGenerator.Config = variant == .qwen08B ? .default0_8B : .default2B
        let gen = Qwen35MLKVGenerator(cfg: cfg)
        gen.setModelFolder(folder)
        // Pin the ANE: never the GPU, so generation keeps working while the app is
        // backgrounded (e.g. driven from the keyboard).
        gen.setComputeUnits(.cpuAndNeuralEngine)
        try await gen.load()

        generator = gen
        tokenizer = tok
        loadedVariant = variant
        logger.info("CoreML Qwen \(variant.rawValue, privacy: .public) ready (ANE)")
        #else
        throw CoreMLQwenError.unavailable
        #endif
    }

    /// Load an already-downloaded variant for generation - throws `.notDownloaded`
    /// if absent, so processing never silently kicks off a multi-GB download.
    func loadForGeneration(variant: CoreMLQwenVariant) async throws {
        guard variant.isDownloaded else { throw CoreMLQwenError.notDownloaded }
        try await ensureLoaded(variant: variant)
    }

    /// Stream a completion for `prompt`. Yields text deltas. Requires a prior load.
    func stream(prompt: String) async throws -> AsyncStream<String> {
        #if canImport(CoreMLLLM)
        guard let gen = generator, let tok = tokenizer else { throw CoreMLQwenError.notLoaded }
        guard !isGenerating else { throw CoreMLQwenError.busy }
        isGenerating = true

        let chat: [[String: any Sendable]] = [["role": "user", "content": prompt]]
        let templated = try? tok.applyChatTemplate(messages: chat)
        let inputIds = (templated ?? tok.encode(text: prompt)).map { Int32($0) }
        var eos: Set<Int32> = [248044, 248045, 248046]
        if let e = tok.eosTokenId { eos.insert(Int32(e)) }
        let maxNew = min(2048 - inputIds.count - 1, 1024)
        guard maxNew >= 1 else {
            isGenerating = false
            throw CoreMLQwenError.promptTooLong
        }

        return AsyncStream { continuation in
            Task {
                var accum: [Int] = []
                var emitted = ""
                do {
                    _ = try await gen.generate(
                        inputIds: inputIds,
                        maxNewTokens: maxNew,
                        temperature: 0.0,
                        topK: 40,
                        topP: 1.0,
                        repetitionPenalty: 1.1,
                        eosTokenIds: eos,
                        onToken: { tokenId in
                            if eos.contains(tokenId) { return }
                            accum.append(Int(tokenId))
                            var current = tok.decode(tokens: accum)
                            // Drop a trailing replacement char from a partial
                            // multi-byte token until the next token completes it.
                            while current.hasSuffix("\u{FFFD}") { current = String(current.dropLast()) }
                            if current.count > emitted.count, current.hasPrefix(emitted) {
                                continuation.yield(String(current.dropFirst(emitted.count)))
                                emitted = current
                            }
                        }
                    )
                } catch {
                    continuation.yield("[Error: \(error.localizedDescription)]")
                }
                continuation.finish()
                await self.endGeneration()
            }
        }
        #else
        throw CoreMLQwenError.unavailable
        #endif
    }

    private func endGeneration() {
        isGenerating = false
    }

    /// Free the model (e.g. on memory pressure). The next load reloads from the
    /// on-disk cache (no re-download).
    public func unload() {
        #if canImport(CoreMLLLM)
        generator = nil
        tokenizer = nil
        #endif
        loadedVariant = nil
        isLoading = false
        logger.info("CoreML Qwen model unloaded")
    }

    public func isDownloaded(_ variant: CoreMLQwenVariant) -> Bool {
        variant.isDownloaded
    }

    public func downloadedBytes(_ variant: CoreMLQwenVariant) -> Int64 {
        #if canImport(CoreMLLLM)
        guard let url = downloader.localModelURL(for: variant.modelInfo) else { return 0 }
        let folder = url.deletingLastPathComponent()
        return Self.directorySize(folder)
        #else
        return 0
        #endif
    }

    public func deleteModel(_ variant: CoreMLQwenVariant) throws {
        guard !isGenerating else { throw CoreMLQwenError.busy }
        if loadedVariant == variant { unload() }
        #if canImport(CoreMLLLM)
        try downloader.delete(variant.modelInfo)
        logger.info("CoreML Qwen \(variant.rawValue, privacy: .public) deleted")
        #endif
    }

    /// Recursive byte size of a downloaded model folder.
    private static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in e {
            let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if v?.isRegularFile == true { total += Int64(v?.fileSize ?? 0) }
        }
        return total
    }
}

public enum CoreMLQwenError: LocalizedError {
    case unavailable
    case notLoaded
    case notDownloaded
    case busy
    case promptTooLong

    public var errorDescription: String? {
        switch self {
        case .unavailable: "On-device Qwen (CoreML) is not available in this build."
        case .notLoaded: "The on-device Qwen model has not been loaded yet."
        case .notDownloaded: "Download the on-device Qwen model in AI Providers settings before using it."
        case .busy: "The on-device Qwen model is already processing another request. Try again in a moment."
        case .promptTooLong: "The text is too long for Qwen's 2048-token context."
        }
    }
}
