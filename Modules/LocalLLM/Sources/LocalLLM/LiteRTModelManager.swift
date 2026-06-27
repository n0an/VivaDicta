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

/// The on-device Gemma variants the app can run. Raw values match the Gemma
/// entries in `AIProvider.local`'s model identifiers (`AIProvider.availableModels`).
public nonisolated enum LiteRTGemmaVariant: String, CaseIterable, Sendable {
    case e2b = "gemma-4-E2B"
    case e4b = "gemma-4-E4B"

    public init(modelID: String) {
        self = LiteRTGemmaVariant(rawValue: modelID) ?? .e2b
    }

    public var displayName: String {
        switch self {
        case .e2b: "Gemma 4 E2B"
        case .e4b: "Gemma 4 E4B"
        }
    }

    /// Short description of what the variant is good for, for settings UI.
    public var subtitle: String {
        switch self {
        case .e2b: "Google Gemma 4. Smaller and faster. Runs on 8 GB-class devices. Broad multilingual support."
        case .e4b: "Google Gemma 4. Larger and higher quality. Best on a 12 GB-class device. Broad multilingual support."
        }
    }

    /// Approximate download size, shown before downloading.
    public var approxDownloadDescription: String {
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

    /// Whether this variant's model file is already on disk. Synchronous so UI
    /// (e.g. the model picker) can filter to downloaded variants without async.
    public var isDownloaded: Bool {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory() else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName).path)
        #else
        return false
        #endif
    }

    /// The recommended variant for a device with the given physical RAM: the
    /// larger, higher-quality E4B on a 12 GB-class device (it needs the
    /// headroom), the lighter E2B otherwise. 12 GB-class devices report a little
    /// under 12 GB, so the gate is 11. Pure (RAM passed in) so it's unit-testable.
    public static func recommendedVariant(forPhysicalMemoryBytes bytes: UInt64) -> LiteRTGemmaVariant {
        let ramGB = Double(bytes) / 1_073_741_824
        return ramGB >= 11 ? .e4b : .e2b
    }

    /// Whether this variant is the best fit for the current device's RAM. Used
    /// to surface a "Recommended" badge in settings. Exactly one variant matches.
    public var isRecommendedForThisDevice: Bool {
        self == LiteRTGemmaVariant.recommendedVariant(forPhysicalMemoryBytes: ProcessInfo.processInfo.physicalMemory)
    }
}

/// The model-lifecycle surface the Gemma settings view model depends on:
/// download (with progress), on-disk presence/size, and delete. Seamed as a
/// protocol so `LiteRTGemmaModelViewModel` can be unit-tested against a mock
/// engine instead of the real `LiteRTModelManager`, which downloads gigabytes
/// and drives the GPU. (Text generation has its own seam: `AITextProvider`.)
public protocol LocalModelEngine: Sendable {
    func ensureLoaded(variant: LiteRTGemmaVariant, onDownloadProgress: (@Sendable (Double) -> Void)?) async throws
    func isDownloaded(_ variant: LiteRTGemmaVariant) async -> Bool
    func downloadedBytes(_ variant: LiteRTGemmaVariant) async -> Int64
    func deleteModel(_ variant: LiteRTGemmaVariant) async throws
}

public actor LiteRTModelManager: LocalModelEngine {
    public static let shared = LiteRTModelManager()

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

    /// True while a model is downloading/loading. Guards against starting a
    /// second load concurrently - two variants loading into memory at once
    /// doubles the footprint and can OOM smaller devices.
    private var isLoading = false

    // MARK: Stuck-flag recovery
    // A GPU load/generation that hangs (e.g. the app is backgrounded mid-load and
    // the Metal command buffer is aborted) would otherwise leave `isLoading` /
    // `isGenerating` stuck `true` forever, poisoning every later request with
    // `.busy` ("already processing another request"). These timestamps let the
    // next attempt detect and clear an implausibly long-held flag. A legitimate
    // model DOWNLOAD can be slow, so it is marked and never auto-cleared.
    private let clock = ContinuousClock()
    private var loadStartedAt: ContinuousClock.Instant?
    private var generationStartedAt: ContinuousClock.Instant?
    private var isDownloadingModel = false
    private let stuckThreshold: Duration = .seconds(120)

    /// Clears a flag held longer than `stuckThreshold` - a sign the underlying GPU
    /// op hung and its cleanup never ran. Never clears an in-flight download.
    private func recoverFromStuckStateIfNeeded() {
        let now = clock.now
        if isLoading, !isDownloadingModel, let started = loadStartedAt, started.duration(to: now) > stuckThreshold {
            logger.warning("LiteRT recovery: clearing stale isLoading (held past timeout) - dropping half-loaded model")
            isLoading = false
            loadStartedAt = nil
            #if canImport(LiteRTFoundation)
            chat = nil
            #endif
            loadedVariant = nil
            state = .notLoaded
        }
        if isGenerating, let started = generationStartedAt, started.duration(to: now) > stuckThreshold {
            logger.warning("LiteRT recovery: clearing stale isGenerating (held past timeout)")
            isGenerating = false
            generationStartedAt = nil
        }
    }

    private init() {}

    var isReady: Bool { state == .ready }

    /// Download (first launch only) and load the requested variant. This is the
    /// download-allowed path - call it only from the explicit Settings download
    /// action; the generation path uses `loadForGeneration`, which never
    /// downloads. Idempotent for the same variant; loading a different variant
    /// unloads the previous one (only one fits in memory at a time).
    /// - Parameters:
    ///   - variant: which Gemma model to load (E2B or E4B).
    ///   - onDownloadProgress: 0...1 fraction during the first-launch download.
    public func ensureLoaded(variant: LiteRTGemmaVariant = .e2b, onDownloadProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        #if canImport(LiteRTFoundation)
        if chat != nil, loadedVariant == variant {
            state = .ready
            return
        }
        // Serialize the lifecycle: refuse a second load while one is in flight
        // (two variants loading at once doubles memory -> OOM risk on smaller
        // devices), and never swap the model out from under a running generation.
        // Set synchronously (no await before the assignment) so the actor can't
        // interleave two callers past this guard.
        recoverFromStuckStateIfNeeded()
        guard !isLoading, !isGenerating else { throw LiteRTModelError.busy }
        isDownloadingModel = !variant.isDownloaded
        isLoading = true
        loadStartedAt = clock.now
        defer { isLoading = false; loadStartedAt = nil; isDownloadingModel = false }

        // Switching variants: drop the previously-loaded model first.
        chat = nil
        loadedVariant = nil
        state = .loading
        do {
            // Low temperature: on-device Gemma does extractive text cleanup. The
            // SDK default (0.8) ran hot enough for the small model to occasionally
            // bleed prompt artifacts into output - e.g. injecting a spurious
            // "Speaker A:" prefix from the prompt's speaker-label rule. Small models
            // hallucinate easily, so keep this low - LiteRT's sampler is fixed at
            // load (can't vary per preset like MLX), so use a single low value.
            let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.2)
            let loaded: LiteRTChat
            switch variant {
            case .e2b:
                // First-class SDK catalog model (enforces its own RAM floor).
                loaded = try await LiteRTChat(.gemma4_E2B, sampler: sampler) { progress in
                    onDownloadProgress?(progress.fraction)
                }
            case .e4b:
                // Loaded by HuggingFace repo (not in the SDK catalog); text-only
                // (empty modalities). No RAM gate by design: the settings screen
                // advises E4B is best on a 12 GB-class device, but we let the user
                // download and try it on smaller devices rather than block them.
                loaded = try await LiteRTChat(
                    huggingFaceRepo: variant.huggingFaceRepo,
                    fileName: variant.fileName,
                    sampler: sampler
                ) { progress in
                    onDownloadProgress?(progress.fraction)
                }
            }
            chat = loaded
            loadedVariant = variant
            state = .ready
            logger.info("LiteRT Gemma \(variant.rawValue) ready")
        } catch {
            state = .failed(error.localizedDescription)
            logger.error("LiteRT Gemma \(variant.rawValue) load failed: \(error.localizedDescription)")
            throw error
        }
        #else
        state = .failed("unavailable")
        throw LiteRTModelError.unavailable
        #endif
    }

    /// Load an already-downloaded variant for generation. Never downloads -
    /// throws `.notDownloaded` if the model is not on disk, so a text-processing
    /// request can never silently start a multi-GB download. The download-allowed
    /// path is `ensureLoaded`, used only by the explicit Settings download action.
    func loadForGeneration(variant: LiteRTGemmaVariant) async throws {
        guard variant.isDownloaded else { throw LiteRTModelError.notDownloaded }
        try await ensureLoaded(variant: variant)
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
        recoverFromStuckStateIfNeeded()
        guard let chat else { throw LiteRTModelError.notLoaded }
        guard !isGenerating else { throw LiteRTModelError.busy }
        // Claim the generation slot synchronously (before any await) so two
        // concurrent callers can't both pass the guard during resetConversation's
        // suspension and start overlapping streams. Release it if the reset fails.
        isGenerating = true
        generationStartedAt = clock.now
        do {
            try await chat.resetConversation()
        } catch {
            isGenerating = false
            generationStartedAt = nil
            throw error
        }
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
        generationStartedAt = nil
    }

    /// Free the model (e.g. on memory pressure or when backgrounded). The next
    /// `ensureLoaded()` reloads from the on-disk cache (no re-download).
    public func unload() {
        #if canImport(LiteRTFoundation)
        chat = nil
        #endif
        loadedVariant = nil
        loadStartedAt = nil
        isLoading = false
        state = .notLoaded
        logger.info("LiteRT Gemma model unloaded")
    }

    /// Whether the given variant has already been downloaded to on-disk cache
    /// (independent of whether it is currently loaded into memory).
    public func isDownloaded(_ variant: LiteRTGemmaVariant) -> Bool {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory() else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent(variant.fileName).path)
        #else
        return false
        #endif
    }

    /// On-disk size of the given variant in bytes (0 if absent).
    public func downloadedBytes(_ variant: LiteRTGemmaVariant) -> Int64 {
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
    public func deleteModel(_ variant: LiteRTGemmaVariant) throws {
        // Don't pull the model out from under a running generation.
        guard !isGenerating else { throw LiteRTModelError.busy }
        if loadedVariant == variant { unload() }
        #if canImport(LiteRTFoundation)
        let dir = try LiteRTChat.defaultStorageDirectory()
        let url = dir.appendingPathComponent(variant.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            logger.info("LiteRT Gemma \(variant.rawValue) deleted from disk")
        }
        #endif
    }
}

enum LiteRTModelError: LocalizedError {
    case unavailable
    case notLoaded
    case notDownloaded
    case busy

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device Gemma (LiteRT) is not available in this build."
        case .notLoaded:
            "The on-device Gemma model has not been loaded yet."
        case .notDownloaded:
            "Download the on-device Gemma model in AI Providers settings before using it."
        case .busy:
            "The on-device Gemma model is already processing another request. Try again in a moment."
        }
    }
}
