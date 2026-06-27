//
//  LocalMLXModelManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Lifecycle + generation for on-device MLX models, mirroring VivaDictaMac's
//  MLXLocalModelService: LLMModelFactory.loadContainer (downloads via the
//  default caches-backed Hub) -> ModelContainer.perform { MLXLMCommon.generate }.
//  Lives in the app target because MLXLLM/MLXLMCommon are linked there.
//

import Foundation
import MLXLLM
import MLXLMCommon
import os

enum LocalMLXError: LocalizedError {
    case notDownloaded
    case busy
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .notDownloaded: "This MLX model isn't downloaded yet. Download it in AI Providers."
        case .busy: "The MLX engine is busy with another model. Try again in a moment."
        case .notLoaded: "The MLX model failed to load."
        }
    }
}

/// Seam for the view model (and tests) so the UI doesn't depend on the actor directly.
protocol LocalMLXModelEngine: Sendable {
    func ensureLoaded(model: LocalMLXModel, progress: @escaping @Sendable (Double) -> Void) async throws
    func isDownloaded(_ model: LocalMLXModel) async -> Bool
    func downloadedBytes(_ model: LocalMLXModel) async -> Int64
    func deleteModel(_ model: LocalMLXModel) async throws
}

actor LocalMLXModelManager: LocalMLXModelEngine {
    static let shared = LocalMLXModelManager()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "LocalMLX")
    private var container: ModelContainer?
    private var loadedModel: LocalMLXModel?
    private var isLoading = false
    private var isGenerating = false

    // MARK: Stuck-flag recovery
    // A GPU load/generation that hangs (app backgrounded mid-op -> aborted Metal
    // command buffer) would otherwise leave `isLoading`/`isGenerating` stuck and
    // poison every later request with `.busy`. These timestamps let the next
    // attempt clear an implausibly long-held flag. An in-flight DOWNLOAD is slow
    // by nature, so it is marked and never auto-cleared.
    private let clock = ContinuousClock()
    private var loadStartedAt: ContinuousClock.Instant?
    private var generationStartedAt: ContinuousClock.Instant?
    private var isDownloadingModel = false
    private let stuckThreshold: Duration = .seconds(120)

    private func recoverFromStuckStateIfNeeded() {
        let now = clock.now
        if isLoading, !isDownloadingModel, let started = loadStartedAt, started.duration(to: now) > stuckThreshold {
            logger.logError("🛡️ MLXManager recoverFromStuckState: clearing stale isLoading - dropping half-loaded model")
            isLoading = false
            loadStartedAt = nil
            container = nil
            loadedModel = nil
        }
        if isGenerating, let started = generationStartedAt, started.duration(to: now) > stuckThreshold {
            logger.logError("🛡️ MLXManager recoverFromStuckState: clearing stale isGenerating")
            isGenerating = false
            generationStartedAt = nil
        }
    }

    private init() {}

    // MARK: - Engine

    func isDownloaded(_ model: LocalMLXModel) -> Bool { model.isDownloaded }
    func downloadedBytes(_ model: LocalMLXModel) -> Int64 { model.downloadedBytes }

    /// Download (if needed) + load into memory. Used by the UI download button.
    func ensureLoaded(model: LocalMLXModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        try await load(model: model, allowDownload: true, progress: progress)
    }

    /// Load for generation - never downloads; throws `.notDownloaded` rather than
    /// silently starting a multi-GB fetch.
    func loadForGeneration(model: LocalMLXModel) async throws {
        if loadedModel == model, container != nil { return }
        guard model.isDownloaded else { throw LocalMLXError.notDownloaded }
        try await load(model: model, allowDownload: false, progress: { _ in })
    }

    func deleteModel(_ model: LocalMLXModel) throws {
        guard !isGenerating else { throw LocalMLXError.busy }
        if loadedModel == model {
            container = nil
            loadedModel = nil
        }
        let dir = model.cacheDirectory
        if FileManager.default.fileExists(atPath: dir.path()) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Generation

    /// Streams generated text chunks. Loads the model first (no download).
    func stream(
        model: LocalMLXModel,
        systemMessage: String,
        userMessage: String,
        temperature: Double = 0.3
    ) async throws -> AsyncThrowingStream<String, Error> {
        recoverFromStuckStateIfNeeded()
        try await loadForGeneration(model: model)
        guard let container else { throw LocalMLXError.notLoaded }
        guard !isGenerating else { throw LocalMLXError.busy }
        isGenerating = true // claimed synchronously before returning the stream
        generationStartedAt = clock.now

        // Capture only Sendable values across the @Sendable boundary; build the
        // (non-Sendable) UserInput inside perform.
        let additionalContext: [String: any Sendable]? =
            model.supportsThinkingToggle ? ["enable_thinking": false] : nil
        let system = systemMessage
        let user = userMessage
        let temp = Float(temperature)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await container.perform { (ctx: ModelContext) in
                        let chat: [Chat.Message] = [
                            .init(role: .system, content: system),
                            .init(role: .user, content: user),
                        ]
                        let userInput = UserInput(chat: chat, additionalContext: additionalContext)
                        let lmInput = try await ctx.processor.prepare(input: userInput)
                        let parameters = GenerateParameters(temperature: temp, topP: 0.95, repetitionPenalty: 1.05)
                        let stream = try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: ctx)
                        for try await generation in stream {
                            if case .chunk(let chunk) = generation {
                                continuation.yield(chunk)
                            }
                        }
                    }
                    await self.finishGenerating()
                    continuation.finish()
                } catch {
                    await self.finishGenerating()
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func finishGenerating() {
        isGenerating = false
        generationStartedAt = nil
    }

    /// Free the loaded model from RAM. The next generation reloads from the
    /// on-disk cache. Used by `OnDeviceModelMemory` for single-resident
    /// enforcement and memory-pressure/background unloading. An in-flight
    /// generation keeps its own reference, so this won't crash it - the model
    /// just deallocates once that generation finishes.
    func unload() {
        container = nil
        loadedModel = nil
        isLoading = false
        logger.logInfo("Unloaded MLX model")
    }

    // MARK: - Load

    private func load(
        model: LocalMLXModel,
        allowDownload: Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        if loadedModel == model, container != nil {
            progress(1)
            return
        }
        recoverFromStuckStateIfNeeded()
        guard !isLoading, !isGenerating else { throw LocalMLXError.busy }
        if !allowDownload, !model.isDownloaded { throw LocalMLXError.notDownloaded }

        isDownloadingModel = !model.isDownloaded
        isLoading = true
        loadStartedAt = clock.now
        defer { isLoading = false; loadStartedAt = nil; isDownloadingModel = false }

        // Unload any previous model first - only one fits in memory.
        container = nil
        loadedModel = nil

        let loaded = try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfiguration(id: model.mlxRepo)
        ) { p in
            progress(p.fractionCompleted)
        }
        container = loaded
        loadedModel = model
        logger.info("Loaded MLX model \(model.rawValue, privacy: .public)")
    }
}
