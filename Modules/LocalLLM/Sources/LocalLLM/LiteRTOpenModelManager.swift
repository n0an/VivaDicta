//
//  LiteRTOpenModelManager.swift
//  LocalLLM
//
//  Created by Anton Novoselov on 2026.06.23
//
//  Open community LLMs (Llama, Ministral, Falcon, DeepSeek) running on-device via
//  LiteRT-LM - the same runtime/engine as Gemma, loaded through the generic
//  `LiteRTChat(huggingFaceRepo:fileName:)` path. They're community `.litertlm`
//  conversions (mlboydaisuke), not Google-first-class like Gemma, so quality
//  varies per model. One manager serves all of them.
//
//  All four repos name their file `model.litertlm`, which would collide in the
//  shared cache - so each model is cached in its own subdirectory.
//

import Foundation
import os

#if canImport(LiteRTFoundation)
import LiteRTFoundation
#endif

/// The on-device open LiteRT models the app can run. Raw values match
/// `AIProvider.localLiteRT` model identifiers.
public nonisolated enum LiteRTOpenModel: String, CaseIterable, Sendable {
    case llama32_3B = "llama-3.2-3b"
    case ministral3B = "ministral-3b"
    case falcon3_3B = "falcon3-3b"
    case deepseekR1_1_5B = "deepseek-r1-qwen-1.5b"

    public init(modelID: String) {
        self = LiteRTOpenModel(rawValue: modelID) ?? .llama32_3B
    }

    public var displayName: String {
        switch self {
        case .llama32_3B: "Llama 3.2 3B"
        case .ministral3B: "Ministral 3B"
        case .falcon3_3B: "Falcon3 3B"
        case .deepseekR1_1_5B: "DeepSeek R1 (Qwen 1.5B)"
        }
    }

    public var subtitle: String {
        switch self {
        case .llama32_3B: "Meta's Llama 3.2, on-device via LiteRT."
        case .ministral3B: "Mistral AI's edge model, on-device via LiteRT."
        case .falcon3_3B: "TII's Falcon3, on-device via LiteRT."
        case .deepseekR1_1_5B: "A small reasoning model. May emit its thinking"
        }
    }

    public var approxDownloadDescription: String {
        switch self {
        case .llama32_3B: "~2.2 GB"
        case .ministral3B: "~2.3 GB"
        case .falcon3_3B: "~1.9 GB"
        case .deepseekR1_1_5B: "~1.0 GB"
        }
    }

    /// Asset name for the card icon (nil falls back to an SF symbol).
    public var iconAsset: String? {
        switch self {
        case .llama32_3B: "ollama" // reuse the Ollama llama mascot for Llama
        case .ministral3B: "mistral"
        case .falcon3_3B: "tii-color"
        case .deepseekR1_1_5B: "deepseek-color"
        }
    }

    var huggingFaceRepo: String {
        switch self {
        case .llama32_3B: "mlboydaisuke/Llama-3.2-3B-Instruct-LiteRT"
        case .ministral3B: "mlboydaisuke/Ministral-3-3B-Instruct-2512-LiteRT"
        case .falcon3_3B: "mlboydaisuke/Falcon3-3B-Instruct-LiteRT"
        case .deepseekR1_1_5B: "mlboydaisuke/DeepSeek-R1-Distill-Qwen-1.5B-LiteRT"
        }
    }

    /// Every repo names its file `model.litertlm`.
    var fileName: String { "model.litertlm" }

    /// Per-model cache subdirectory so the identically-named files don't collide.
    var storageSubdirectory: String { rawValue }

    #if canImport(LiteRTFoundation)
    /// Absolute cache file URL (does not create the directory).
    var cacheFileURL: URL? {
        guard let base = try? LiteRTChat.defaultStorageDirectory() else { return nil }
        return base.appendingPathComponent(storageSubdirectory).appendingPathComponent(fileName)
    }
    #endif

    public var isDownloaded: Bool {
        #if canImport(LiteRTFoundation)
        guard let url = cacheFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
        #else
        return false
        #endif
    }
}

public protocol LiteRTOpenModelEngine: Sendable {
    func ensureLoaded(model: LiteRTOpenModel, onDownloadProgress: (@Sendable (Double) -> Void)?) async throws
    func isDownloaded(_ model: LiteRTOpenModel) async -> Bool
    func downloadedBytes(_ model: LiteRTOpenModel) async -> Int64
    func deleteModel(_ model: LiteRTOpenModel) async throws
}

public actor LiteRTOpenModelManager: LiteRTOpenModelEngine {
    public static let shared = LiteRTOpenModelManager()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "LiteRTOpen")

    #if canImport(LiteRTFoundation)
    private var chat: LiteRTChat?
    #endif

    private(set) var loadedModel: LiteRTOpenModel?
    private var isGenerating = false
    private var isLoading = false

    private init() {}

    /// Download (first launch only) + load. Download-allowed path - Settings only.
    public func ensureLoaded(model: LiteRTOpenModel = .llama32_3B, onDownloadProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        #if canImport(LiteRTFoundation)
        if chat != nil, loadedModel == model { return }
        guard !isLoading, !isGenerating else { throw LiteRTOpenModelError.busy }
        isLoading = true
        defer { isLoading = false }
        chat = nil
        loadedModel = nil

        // Per-model cache directory so the shared "model.litertlm" filename
        // doesn't collide across models.
        let base = try LiteRTChat.defaultStorageDirectory()
        let dir = base.appendingPathComponent(model.storageSubdirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Low temperature: on-device text cleanup, same profile as Gemma.
        let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.3)
        let loaded = try await LiteRTChat(
            huggingFaceRepo: model.huggingFaceRepo,
            fileName: model.fileName,
            storageDirectory: dir,
            sampler: sampler
        ) { progress in
            onDownloadProgress?(progress.fraction)
        }
        chat = loaded
        loadedModel = model
        logger.info("LiteRT open model \(model.rawValue) ready")
        #else
        throw LiteRTOpenModelError.unavailable
        #endif
    }

    /// Load an already-downloaded model for generation - never downloads.
    func loadForGeneration(model: LiteRTOpenModel) async throws {
        guard model.isDownloaded else { throw LiteRTOpenModelError.notDownloaded }
        try await ensureLoaded(model: model)
    }

    func stream(prompt: String) async throws -> AsyncThrowingStream<String, any Error> {
        #if canImport(LiteRTFoundation)
        guard let chat else { throw LiteRTOpenModelError.notLoaded }
        guard !isGenerating else { throw LiteRTOpenModelError.busy }
        isGenerating = true
        do {
            try await chat.resetConversation()
        } catch {
            isGenerating = false
            throw error
        }
        let base = chat.stream(prompt)
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
        throw LiteRTOpenModelError.unavailable
        #endif
    }

    private func endGeneration() {
        isGenerating = false
    }

    func unload() {
        #if canImport(LiteRTFoundation)
        chat = nil
        #endif
        loadedModel = nil
    }

    public func isDownloaded(_ model: LiteRTOpenModel) -> Bool {
        model.isDownloaded
    }

    public func downloadedBytes(_ model: LiteRTOpenModel) -> Int64 {
        #if canImport(LiteRTFoundation)
        guard let url = model.cacheFileURL else { return 0 }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
        #else
        return 0
        #endif
    }

    public func deleteModel(_ model: LiteRTOpenModel) throws {
        guard !isGenerating else { throw LiteRTOpenModelError.busy }
        if loadedModel == model { unload() }
        #if canImport(LiteRTFoundation)
        if let url = model.cacheFileURL, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            logger.info("LiteRT open model \(model.rawValue) deleted")
        }
        #endif
    }
}

public enum LiteRTOpenModelError: LocalizedError {
    case unavailable
    case notLoaded
    case notDownloaded
    case busy

    public var errorDescription: String? {
        switch self {
        case .unavailable: "On-device LiteRT open models are not available in this build."
        case .notLoaded: "The on-device model has not been loaded yet."
        case .notDownloaded: "Download the on-device model in AI Providers settings before using it."
        case .busy: "The on-device model is already processing another request. Try again in a moment."
        }
    }
}
