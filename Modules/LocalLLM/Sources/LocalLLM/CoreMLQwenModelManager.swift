//
//  CoreMLQwenModelManager.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.23
//
//  Owns the on-device Qwen3.5 model (CoreML-LLM, ANE), loaded once and reused -
//  the CoreML counterpart to LiteRTModelManager. Qwen3.5 uses the low-level
//  Qwen35MLKVGenerator (token-ids in/out), so this also owns the tokenizer
//  (swift-transformers) and the download (ModelDownloader). Verified end-to-end
//  by the earlier CoreMLQwenSpike.
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
#endif

/// The on-device Qwen variants the app can run. Raw values match
/// `AIProvider.localQwen` model identifiers (and CoreML-LLM's ModelInfo ids).
public nonisolated enum CoreMLQwenVariant: String, CaseIterable, Sendable {
    case qwen2B = "qwen3.5-2b"
    case qwen08B = "qwen3.5-0.8b"

    public init(modelID: String) {
        self = CoreMLQwenVariant(rawValue: modelID) ?? .qwen2B
    }

    public var displayName: String {
        switch self {
        case .qwen2B: "Qwen3.5 2B"
        case .qwen08B: "Qwen3.5 0.8B"
        }
    }

    public var subtitle: String {
        switch self {
        case .qwen2B: "Higher quality. Runs on the Neural Engine - very low memory, slower than GPU models."
        case .qwen08B: "Smallest and lightest, fastest to download. Lower quality than 2B."
        }
    }

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
/// `LocalModelEngine` for Gemma; the shared abstraction is a later follow-up).
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
            // load wants the folder CONTAINING the chunks subdir; localModelURL
            // points one level in (matches CoreML-LLM's own example).
            folder = url.deletingLastPathComponent()
        } else {
            onDownloadProgress?(0)
            let url = try await downloader.download(info)
            onDownloadProgress?(1)
            folder = url.deletingLastPathComponent()
        }

        let tok = try await AutoTokenizer.from(pretrained: variant.tokenizerId)
        let cfg: Qwen35MLKVGenerator.Config = variant == .qwen08B ? .default0_8B : .default2B
        let gen = Qwen35MLKVGenerator(cfg: cfg)
        gen.setModelFolder(folder)
        try await gen.load()

        generator = gen
        tokenizer = tok
        loadedVariant = variant
        logger.info("CoreML Qwen \(variant.rawValue) ready")
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

    func unload() {
        #if canImport(CoreMLLLM)
        generator = nil
        tokenizer = nil
        #endif
        loadedVariant = nil
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
        logger.info("CoreML Qwen \(variant.rawValue) deleted")
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
