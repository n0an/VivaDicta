//
//  LiteRTGemmaModelViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.22
//
//  Exercises the download/cancel/delete/refresh state machine of
//  `LiteRTGemmaModelViewModel` against a `MockLocalModelEngine`, so none of it
//  touches a real multi-gigabyte download or the GPU. `prepare(_:)` returns its
//  in-flight task, so tests await completion instead of polling.
//

import Foundation
import Testing
@testable import VivaDicta

@MainActor
struct LiteRTGemmaModelViewModelTests {

    // MARK: - Helpers

    /// Pattern-matches a `.failed` status without asserting the (implementation
    /// detail) message text.
    private func isFailed(_ status: LiteRTGemmaModelViewModel.Status) -> Bool {
        if case .failed = status { return true }
        return false
    }

    private func isDownloading(_ status: LiteRTGemmaModelViewModel.Status) -> Bool {
        if case .downloading = status { return true }
        return false
    }

    private struct StubError: Error {}

    // MARK: - prepare: happy path

    @Test func prepare_success_setsReadyAndRecordsSize() async {
        let mock = MockLocalModelEngine(bytesAfterDownload: 2_600_000_000)
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.prepare(.e2b).value

        #expect(sut.status(for: .e2b) == .ready)
        #expect(sut.sizeBytes[.e2b] == 2_600_000_000)
        #expect(await mock.ensureLoadedCalls == [.e2b])
    }

    @Test func prepare_withProgress_stillEndsReady() async {
        // Progress callbacks must not wedge the terminal state.
        let mock = MockLocalModelEngine(progressSequence: [0.25, 0.5, 1.0])
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.prepare(.e2b).value

        #expect(sut.status(for: .e2b) == .ready)
    }

    // MARK: - prepare: failures

    @Test func prepare_genericFailure_setsFailed() async {
        let mock = MockLocalModelEngine(ensureLoadedError: StubError())
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.prepare(.e2b).value

        let status = sut.status(for: .e2b)
        #expect(isFailed(status), "Expected .failed, got \(status)")
    }

    @Test func prepare_cancellationError_setsNotDownloaded() async {
        // A thrown CancellationError is a cancel, not a failure.
        let mock = MockLocalModelEngine(ensureLoadedError: CancellationError())
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.prepare(.e2b).value

        #expect(sut.status(for: .e2b) == .notDownloaded)
    }

    @Test func prepare_urlCancelledError_setsNotDownloaded() async {
        // URLSession surfaces cancellation as URLError(.cancelled); also a cancel.
        let mock = MockLocalModelEngine(ensureLoadedError: URLError(.cancelled))
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.prepare(.e2b).value

        #expect(sut.status(for: .e2b) == .notDownloaded)
    }

    // MARK: - cancel

    @Test func cancel_inFlightDownload_setsNotDownloaded() async {
        let mock = MockLocalModelEngine(blockUntilCancelled: true)
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        let task = sut.prepare(.e2b)
        sut.cancel(.e2b)
        await task.value

        #expect(sut.status(for: .e2b) == .notDownloaded)
    }

    // MARK: - refresh

    @Test func refresh_downloadedVariant_setsReadyWithSize() async {
        let mock = MockLocalModelEngine(downloaded: [.e2b], bytes: [.e2b: 1_234])
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.refresh()

        #expect(sut.status(for: .e2b) == .ready)
        #expect(sut.sizeBytes[.e2b] == 1_234)
    }

    @Test func refresh_notDownloadedVariant_setsNotDownloaded() async {
        let mock = MockLocalModelEngine(downloaded: [])
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.refresh()

        #expect(sut.status(for: .e4b) == .notDownloaded)
    }

    @Test func refresh_doesNotClobberInFlightDownload() async {
        let mock = MockLocalModelEngine(blockUntilCancelled: true)
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        let task = sut.prepare(.e2b) // status -> .downloading(0), blocks
        await sut.refresh()          // must skip the in-flight variant

        let status = sut.status(for: .e2b)
        #expect(isDownloading(status), "Expected .downloading (in-flight), got \(status)")

        sut.cancel(.e2b)             // clean up the blocked task
        await task.value
    }

    // MARK: - delete

    @Test func delete_downloadedVariant_setsNotDownloadedAndZeroSize() async {
        let mock = MockLocalModelEngine(downloaded: [.e2b], bytes: [.e2b: 2_600_000_000])
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.delete(.e2b)

        #expect(sut.status(for: .e2b) == .notDownloaded)
        #expect(sut.sizeBytes[.e2b] == 0)
        #expect(await mock.deleteCalls == [.e2b])
    }

    @Test func delete_failure_setsFailed() async {
        let mock = MockLocalModelEngine(downloaded: [.e2b], deleteError: StubError())
        let sut = LiteRTGemmaModelViewModel(engine: mock)

        await sut.delete(.e2b)

        let status = sut.status(for: .e2b)
        #expect(isFailed(status), "Expected .failed, got \(status)")
    }
}
