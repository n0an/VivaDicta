//
//  MockLocalMLXModelEngine.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Test double for `LocalMLXModelEngine` - the model-lifecycle seam behind the
//  MLX model view model. Lets view-model tests drive download / cancel / delete
//  / failure paths deterministically, with no real Hub download and no GPU.
//  Actor (so it's Sendable like the real manager), captures calls (spy), and its
//  behavior is configured at init (stub). Mirrors LocalLLMMocks.MockLocalModelEngine.
//

import Foundation
import LocalLLM
@testable import VivaDicta

actor MockLocalMLXModelEngine: LocalMLXModelEngine {

    // MARK: Spies

    private(set) var ensureLoadedCalls: [LocalMLXModel] = []
    private(set) var deleteCalls: [LocalMLXModel] = []

    // MARK: Stubbed state

    private var downloaded: Set<LocalMLXModel>
    private var bytes: [LocalMLXModel: Int64]

    // MARK: Configuration

    private let progressSequence: [Double]
    private let blockUntilCancelled: Bool
    private let bytesAfterDownload: Int64
    private let ensureLoadedError: (any Error)?
    private let deleteError: (any Error)?

    init(
        downloaded: Set<LocalMLXModel> = [],
        bytes: [LocalMLXModel: Int64] = [:],
        progressSequence: [Double] = [],
        blockUntilCancelled: Bool = false,
        bytesAfterDownload: Int64 = 1_300_000_000,
        ensureLoadedError: (any Error)? = nil,
        deleteError: (any Error)? = nil
    ) {
        self.downloaded = downloaded
        self.bytes = bytes
        self.progressSequence = progressSequence
        self.blockUntilCancelled = blockUntilCancelled
        self.bytesAfterDownload = bytesAfterDownload
        self.ensureLoadedError = ensureLoadedError
        self.deleteError = deleteError
    }

    // MARK: LocalMLXModelEngine

    func ensureLoaded(model: LocalMLXModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        ensureLoadedCalls.append(model)
        for fraction in progressSequence {
            try Task.checkCancellation()
            progress(fraction)
        }
        if blockUntilCancelled {
            // Long sleep; a cancelled task throws CancellationError here.
            try await Task.sleep(for: .seconds(60))
        }
        if let ensureLoadedError {
            throw ensureLoadedError
        }
        downloaded.insert(model)
        bytes[model] = bytesAfterDownload
    }

    func isDownloaded(_ model: LocalMLXModel) -> Bool {
        downloaded.contains(model)
    }

    func downloadedBytes(_ model: LocalMLXModel) -> Int64 {
        bytes[model] ?? 0
    }

    func deleteModel(_ model: LocalMLXModel) throws {
        deleteCalls.append(model)
        if let deleteError {
            throw deleteError
        }
        downloaded.remove(model)
        bytes[model] = nil
    }
}
