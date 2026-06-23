//
//  MockLocalModelEngine.swift
//  LocalLLMMocks
//
//  Created by Anton Novoselov on 2026.06.22
//
//  Test double for `LocalModelEngine` - the model-lifecycle seam behind the
//  on-device model view models. Lets view-model tests drive download / cancel /
//  delete / failure paths deterministically, with no real download and no GPU.
//  It's an actor (so it's `Sendable` like the real manager), it captures calls
//  (spy), and its behavior is configured at init (stub).
//

import Foundation
import LocalLLM

public actor MockLocalModelEngine: LocalModelEngine {

    // MARK: Spies (what the view model asked us to do)

    public private(set) var ensureLoadedCalls: [LiteRTGemmaVariant] = []
    public private(set) var deleteCalls: [LiteRTGemmaVariant] = []

    // MARK: Stubbed state

    private var downloaded: Set<LiteRTGemmaVariant>
    private var bytes: [LiteRTGemmaVariant: Int64]

    // MARK: Configuration (immutable, set at init)

    /// Progress fractions emitted (in order) during `ensureLoaded` before it returns.
    private let progressSequence: [Double]
    /// When true, `ensureLoaded` suspends until the task is cancelled - lets a
    /// test cancel an in-flight download deterministically.
    private let blockUntilCancelled: Bool
    /// Disk size reported for a variant after a successful `ensureLoaded`.
    private let bytesAfterDownload: Int64
    /// When set, `ensureLoaded` throws this instead of succeeding.
    private let ensureLoadedError: (any Error)?
    /// When set, `deleteModel` throws this instead of succeeding.
    private let deleteError: (any Error)?

    public init(
        downloaded: Set<LiteRTGemmaVariant> = [],
        bytes: [LiteRTGemmaVariant: Int64] = [:],
        progressSequence: [Double] = [],
        blockUntilCancelled: Bool = false,
        bytesAfterDownload: Int64 = 2_600_000_000,
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

    // MARK: LocalModelEngine

    public func ensureLoaded(variant: LiteRTGemmaVariant, onDownloadProgress: (@Sendable (Double) -> Void)?) async throws {
        ensureLoadedCalls.append(variant)
        for fraction in progressSequence {
            try Task.checkCancellation()
            onDownloadProgress?(fraction)
        }
        if blockUntilCancelled {
            // Long sleep; a cancelled task throws CancellationError here.
            try await Task.sleep(for: .seconds(60))
        }
        if let ensureLoadedError {
            throw ensureLoadedError
        }
        downloaded.insert(variant)
        bytes[variant] = bytesAfterDownload
    }

    public func isDownloaded(_ variant: LiteRTGemmaVariant) -> Bool {
        downloaded.contains(variant)
    }

    public func downloadedBytes(_ variant: LiteRTGemmaVariant) -> Int64 {
        bytes[variant] ?? 0
    }

    public func deleteModel(_ variant: LiteRTGemmaVariant) throws {
        deleteCalls.append(variant)
        if let deleteError {
            throw deleteError
        }
        downloaded.remove(variant)
        bytes[variant] = nil
    }
}
