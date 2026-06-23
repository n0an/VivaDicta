//
//  CoreMLQwenSpike.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.23
//
//  On-device verification harness for Qwen3.5 via CoreML-LLM's low-level
//  Qwen35MLKVGenerator. Proves the download -> tokenizer -> load -> generate
//  flow actually produces text on a physical device (ANE), before we wire a
//  full AITextProvider/manager around it. Mirrors the package's own
//  Examples/CoreMLLLMChat/LLMRunner.swift (loadQwen35MLKV + generateQwen35MLKV).
//
//  This is NOT the production provider - it's a spike. Driven by a DEBUG-only
//  settings screen.
//

import Foundation
import os

#if canImport(CoreMLLLM)
// CoreMLLLM's generator + tokenizer are non-Sendable @Observable classes with
// nonisolated async methods; @preconcurrency keeps strict-concurrency checks on
// them as warnings so we can drive them from this module's isolation.
@preconcurrency import CoreMLLLM
@preconcurrency import Tokenizers
#endif

/// Thread-safe token collector so the `onToken` closure passed to a nonisolated
/// async `generate` captures only Sendable state.
private final class TokenSink: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [Int32] = []
    func append(_ id: Int32) {
        lock.lock(); defer { lock.unlock() }
        ids.append(id)
    }
    var all: [Int32] {
        lock.lock(); defer { lock.unlock() }
        return ids
    }
}

@MainActor
@Observable
public final class CoreMLQwenSpike {
    public enum Variant: String, Sendable, CaseIterable, Identifiable {
        case qwen2B = "qwen3.5-2b"
        case qwen08B = "qwen3.5-0.8b"
        public var id: String { rawValue }
        public var displayName: String { self == .qwen2B ? "Qwen3.5 2B" : "Qwen3.5 0.8B" }
        public var approxSize: String { self == .qwen2B ? "~2.8 GB" : "~1.2 GB" }
    }

    public private(set) var status = "Idle"
    public private(set) var output = ""
    public private(set) var isRunning = false
    public private(set) var tokensPerSecond: Double = 0

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "CoreMLQwenSpike")

    #if canImport(CoreMLLLM)
    private let downloader = ModelDownloader.shared
    private var generator: Qwen35MLKVGenerator?
    private var tokenizer: (any Tokenizer)?
    private var loadedVariant: Variant?

    private func modelInfo(_ v: Variant) -> ModelDownloader.ModelInfo {
        v == .qwen2B ? .qwen35_2b : .qwen35_08b
    }
    #endif

    public init() {}

    public func isDownloaded(_ variant: Variant) -> Bool {
        #if canImport(CoreMLLLM)
        downloader.isDownloaded(modelInfo(variant))
        #else
        false
        #endif
    }

    /// Download (if needed) + load + generate one prompt, streaming text into `output`.
    public func run(variant: Variant, prompt: String) async {
        guard !isRunning else { return }
        isRunning = true
        output = ""
        tokensPerSecond = 0
        defer { isRunning = false }

        #if canImport(CoreMLLLM)
        do {
            try await ensureLoaded(variant)
            guard let gen = generator, let tok = tokenizer else {
                status = "Not loaded"
                return
            }

            // Chat template, falling back to raw encode (the package warns
            // Qwen3.5's Jinja template may not apply on iPhone's swift-transformers).
            let chat: [[String: any Sendable]] = [["role": "user", "content": prompt]]
            let templated = try? tok.applyChatTemplate(messages: chat)
            let inputIds = (templated ?? tok.encode(text: prompt)).map { Int32($0) }
            status = "Generating (chatTemplate=\(templated != nil), \(inputIds.count) input tokens)..."

            let remaining = 2048 - inputIds.count - 1
            guard remaining >= 1 else {
                status = "Prompt too long (\(inputIds.count) tokens, max 2048)"
                return
            }
            let maxNew = min(remaining, 512)

            var eos: Set<Int32> = [248044, 248045, 248046]
            if let e = tok.eosTokenId { eos.insert(Int32(e)) }

            // Collect token ids into a thread-safe sink so the onToken closure
            // captures only Sendable values (it's handed to a nonisolated async
            // generate). Decode once after the await completes, on the main actor.
            // A spike doesn't need live streaming.
            let sink = TokenSink()
            let eosTokens = eos
            let start = Date()
            _ = try await gen.generate(
                inputIds: inputIds,
                maxNewTokens: maxNew,
                temperature: 0.0,
                topK: 40,
                topP: 1.0,
                repetitionPenalty: 1.1,
                eosTokenIds: eosTokens,
                onToken: { tokenId in
                    if eosTokens.contains(tokenId) { return }
                    sink.append(tokenId)
                }
            )
            let dt = Date().timeIntervalSince(start)
            let ids = sink.all
            var text = tok.decode(tokens: ids.map { Int($0) })
            while text.hasSuffix("\u{FFFD}") { text = String(text.dropLast()) }
            output = text
            tokensPerSecond = dt > 0 ? Double(ids.count) / dt : 0
            status = "Done - \(ids.count) tokens"
            logger.info("CoreML Qwen spike generated \(ids.count) tokens")
        } catch {
            status = "Error: \(error.localizedDescription)"
            logger.error("CoreML Qwen spike failed: \(error.localizedDescription)")
        }
        #else
        status = "CoreML-LLM unavailable in this build"
        #endif
    }

    #if canImport(CoreMLLLM)
    private func ensureLoaded(_ variant: Variant) async throws {
        if generator != nil, loadedVariant == variant { return }
        generator = nil
        tokenizer = nil
        loadedVariant = nil

        let info = modelInfo(variant)
        let folder: URL
        if downloader.isDownloaded(info), let url = downloader.localModelURL(for: info) {
            // load wants the folder CONTAINING the chunks subdir; localModelURL
            // points one level in (matches the example's loadModel stripping).
            folder = url.deletingLastPathComponent()
        } else {
            status = "Downloading \(variant.displayName) (\(info.size)) - first run only..."
            let url = try await downloader.download(info)
            folder = url.deletingLastPathComponent()
        }

        status = "Loading Qwen tokenizer..."
        let tokId = variant == .qwen08B ? "Qwen/Qwen3.5-0.8B" : "Qwen/Qwen3.5-2B"
        let tok = try await AutoTokenizer.from(pretrained: tokId)

        status = "Compiling Qwen3.5 chunks (first run can take minutes on the ANE)..."
        let cfg: Qwen35MLKVGenerator.Config = variant == .qwen08B ? .default0_8B : .default2B
        let gen = Qwen35MLKVGenerator(cfg: cfg)
        gen.setModelFolder(folder)
        try await gen.load()

        generator = gen
        tokenizer = tok
        loadedVariant = variant
        logger.info("CoreML Qwen spike loaded \(variant.rawValue)")
    }
    #endif
}
