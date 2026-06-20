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

    private init() {}

    var isReady: Bool { state == .ready }

    /// Download (first launch only) and load the model. Idempotent - returns
    /// immediately when already loaded.
    /// - Parameter onDownloadProgress: 0...1 fraction during the first-launch download.
    func ensureLoaded(onDownloadProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        #if canImport(LiteRTFoundation)
        if chat != nil {
            state = .ready
            return
        }
        state = .loading
        do {
            let loaded = try await LiteRTChat(.gemma4_E2B) { progress in
                onDownloadProgress?(progress.fraction)
            }
            chat = loaded
            state = .ready
            logger.logInfo("LiteRT Gemma model ready")
        } catch {
            state = .failed(error.localizedDescription)
            logger.logError("LiteRT Gemma load failed: \(error.localizedDescription)")
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
    func stream(prompt: String) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(LiteRTFoundation)
        guard let chat else { throw LiteRTModelError.notLoaded }
        try await chat.resetConversation()
        return chat.stream(prompt)
        #else
        throw LiteRTModelError.unavailable
        #endif
    }

    /// Free the model (e.g. on memory pressure or when backgrounded). The next
    /// `ensureLoaded()` reloads from the on-disk cache (no re-download).
    func unload() {
        #if canImport(LiteRTFoundation)
        chat = nil
        #endif
        state = .notLoaded
        logger.logInfo("LiteRT Gemma model unloaded")
    }

    /// Whether the model file has already been downloaded to on-disk cache
    /// (independent of whether it is currently loaded into memory).
    var isDownloaded: Bool {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory() else { return false }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return files.contains { $0.hasSuffix(".litertlm") }
        #else
        return false
        #endif
    }

    /// Approximate on-disk size of the downloaded model in bytes (0 if absent).
    var downloadedBytes: Int64 {
        #if canImport(LiteRTFoundation)
        guard let dir = try? LiteRTChat.defaultStorageDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
        #else
        return 0
        #endif
    }

    /// Unload the model and delete its on-disk cache, reclaiming the ~2.6 GB.
    /// The next `ensureLoaded()` re-downloads.
    func deleteModel() throws {
        unload()
        #if canImport(LiteRTFoundation)
        let dir = try LiteRTChat.defaultStorageDirectory()
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
            logger.logInfo("LiteRT Gemma model deleted from disk")
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

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device Gemma (LiteRT) is not available in this build."
        case .notLoaded:
            "The on-device Gemma model has not been loaded yet."
        }
    }
}
