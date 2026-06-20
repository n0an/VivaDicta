//
//  LiteRTModelManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Owns the single on-device Gemma model (LiteRT-LM), loaded once and reused.
//  On-device LLM is a heavyweight, stateful resource (model download + load +
//  GPU kernel compile), so exactly one instance lives behind this actor and is
//  shared across the app. See llmtemp/litert-gemma-integration-plan.md.
//
//  LiteRT calls are guarded by `#if canImport(LiteRTFoundation)` so the app
//  still builds if the package is unlinked. The package is the n0an fork of
//  swift-litert-lm (FM folder excluded so easy mode builds on the iOS 26 SDK).
//

import Foundation
import os

#if canImport(LiteRTFoundation)
import LiteRTFoundation
#endif

/// The on-device Gemma variants the app can run. Raw values match the
/// `AIProvider.localGemma` model identifiers (`AIProvider.availableModels`).
nonisolated enum LiteRTGemmaVariant: String, CaseIterable, Sendable {
    case e2b = "gemma-4-E2B"
    case e4b = "gemma-4-E4B"

    init(modelID: String) {
        self = LiteRTGemmaVariant(rawValue: modelID) ?? .e2b
    }

    var displayName: String {
        switch self {
        case .e2b: "Gemma 4 E2B"
        case .e4b: "Gemma 4 E4B"
        }
    }

    /// Short description of what the variant is good for, for settings UI.
    var subtitle: String {
        switch self {
        case .e2b: "Smaller and faster. Runs on 8 GB-class devices."
        case .e4b: "Larger and higher quality. Needs a 12 GB-class device."
        }
    }

    /// Approximate download size, shown before downloading.
    var approxDownloadDescription: String {
        switch self {
        case .e2b: "~2.6 GB"
        case .e4b: "~4.4 GB"
        }
    }

    /// On-disk filename the SDK caches the `.litertlm` under.
    var fileName: String {
        switch self {
        case .e2b: "gemma-4-E2B-it.litertlm"
        case .e4b: "gemma-4-E4B-it.litertlm"
        }
    }

    /// HuggingFace repo for variants loaded outside the SDK catalog (E4B).
    var huggingFaceRepo: String {
        switch self {
        case .e2b: "litert-community/gemma-4-E2B-it-litert-lm"
        case .e4b: "litert-community/gemma-4-E4B-it-litert-lm"
        }
    }

    /// Minimum device RAM to attempt loading. E2B targets 8 GB-class devices
    /// (the SDK catalog enforces its own floor); E4B is far larger and only
    /// sensible on 12 GB-class devices, so we gate it to avoid jetsam.
    var minimumDeviceRAM: Int64 {
        switch self {
        case .e2b: 7_000_000_000
        case .e4b: 11_000_000_000
        }
    }
}

actor LiteRTModelManager {
    static let shared = LiteRTModelManager()

    enum State: Sendable, Equatable {
        case notLoaded
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .notLoaded
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "LiteRT")

    #if canImport(LiteRTFoundation)
    private var chat: LiteRTChat?
    #endif

    /// The variant currently loaded into memory (nil when unloaded).
    private(set) var loadedVariant: LiteRTGemmaVariant?

    /// Guards against overlapping generations: a single shared engine/conversation
    /// cannot serve two streams at once (the second's reset would swap the
    /// conversation mid-flight). One generation runs at a time.
    private var isGenerating = false

    private init() {}

    var isReady: Bool { state == .ready }

    /// Download (first launch only) and load the requested variant. Idempotent
    /// for the same variant; loading a different variant unloads the previous one
    /// (only one fits in memory at a time).
    /// - Parameters:
    ///   - variant: which Gemma model to load (E2B or E4B).
    ///   - onDownloadProgress: 0...1 fraction during the first-launch download.
    func ensureLoaded(variant: LiteRTGemmaVariant = .e2b, onDownloadProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        #if canImport(LiteRTFoundation)
        if chat != nil, loadedVariant == variant {
            state = .ready
            return
        }
        // Switching variants: drop the previously-loaded model first.
        chat = nil
        loadedVariant = nil
        state = .loading
        do {
            // Low temperature: on-device Gemma does extractive text cleanup. The
            // SDK default (0.8) ran hot enough for the small model to occasionally
            // bleed prompt artifacts into output - e.g. injecting a spurious
            // "Speaker A:" prefix from the prompt's speaker-label rule. 0.3 mirrors
            // Apple FM's "balanced" profile and is far steadier.
            let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.3)
            let loaded: LiteRTChat
            switch variant {
            case .e2b:
                // First-class SDK catalog model (enforces its own RAM floor).
                loaded = try await LiteRTChat(.gemma4_E2B, sampler: sampler) { progress in
                    onDownloadProgress?(progress.fraction)
                }
            case .e4b:
                // Loaded by HuggingFace repo (not in the SDK catalog); text-only
                // (empty modalities) and RAM-gated to 12 GB-class devices.
                loaded = try await LiteRTChat(
                    huggingFaceRepo: variant.huggingFaceRepo,
                    fileName: variant.fileName,
                    minimumDeviceRAM: variant.minimumDeviceRAM,
                    sampler: sampler
                ) { progress in
                    onDownloadProgress?(progress.fraction)
                }
            }
            chat = loaded
            loadedVariant = variant
            state = .ready
            logger.logInfo("LiteRT Gemma \(variant.rawValue) ready")
        } catch {
            state = .failed(error.localizedDescription)
            logger.logError("LiteRT Gemma \(variant.rawValue) load failed: \(error.localizedDescription)")
            throw error
        }
        #else
        state = .failed("unavailable")
        throw LiteRTModelError.unavailable
        #endif
    }

    /// Stream a completion for a fully-built prompt. Yields delta chunks (not
    /// cumulative); callers accumulate. Requires `ensureLoaded()` first.
    ///
    /// Each call resets the conversation first: text enhancement is independent
    /// and single-turn, so without a reset the persistent conversation would
    /// accumulate every prior prompt and overflow the context window (empty
    /// output after a few runs).
    func stream(prompt: String) async throws -> AsyncThrowingStream<String, any Error> {
        #if canImport(LiteRTFoundation)
        guard let chat else { throw LiteRTModelError.notLoaded }
        guard !isGenerating else { throw LiteRTModelError.busy }
        try await chat.resetConversation()
        isGenerating = true
        let base = chat.stream(prompt)
        // Wrap so the in-flight flag clears when the stream finishes or the
        // consumer abandons it (cancellation), keeping the engine serial.
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await delta in base { continuation.yield(delta) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                self.endGeneration()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        throw LiteRTModelError.unavailable
        #endif
    }

    private func endGeneration() {
        isGenerating = false
    }

    /// Free the model (e.g. on memory pressure or when backgrounded). The next
    /// `ensureLoaded()` reloads from the on-disk cache (no re-download).
    func unload() {
        #if canImport(LiteRTFoundation)
        chat = nil
        #endif
        loadedVariant = nil
        state = .notLoaded
        logger.logInfo("LiteRT Gemma model unloaded")
    }

    /// Whether the given variant has already been downloaded to on-disk cache
    /// (independent of whether it is currently loaded into memory).
    func isDownloaded(_ variant: LiteRTGemmaVariant) -> Bool {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory() else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(variant.fileName).path)
        #else
        return false
        #endif
    }

    /// On-disk size of the given variant in bytes (0 if absent).
    func downloadedBytes(_ variant: LiteRTGemmaVariant) -> Int64 {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory() else { return 0 }
        let url = dir.appendingPathComponent(variant.fileName)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
        #else
        return 0
        #endif
    }

    /// Delete the given variant's on-disk cache, reclaiming its space (unloading
    /// it first if it is the currently-loaded one). The next `ensureLoaded()`
    /// re-downloads it.
    func deleteModel(_ variant: LiteRTGemmaVariant) throws {
        if loadedVariant == variant { unload() }
        #if canImport(LiteRTFoundation)
        let dir = try LiteRTChat.defaultStorageDirectory()
        let url = dir.appendingPathComponent(variant.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            logger.logInfo("LiteRT Gemma \(variant.rawValue) deleted from disk")
        }
        #endif
    }

    /// Current process memory footprint in MB (phys_footprint), for diagnostics.
    nonisolated static func memoryFootprintMB() -> Double {
        #if canImport(LiteRTFoundation)
        Double(LiteRTChat.memoryFootprintBytes()) / 1_048_576
        #else
        0
        #endif
    }
}

enum LiteRTModelError: LocalizedError {
    case unavailable
    case notLoaded
    case busy

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device Gemma (LiteRT) is not available in this build."
        case .notLoaded:
            "The on-device Gemma model has not been loaded yet."
        case .busy:
            "The on-device Gemma model is already processing another request. Try again in a moment."
        }
    }
}
