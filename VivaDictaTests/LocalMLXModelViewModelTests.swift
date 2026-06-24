//
//  LocalMLXModelViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Exercises the download/cancel/delete/refresh state machine of
//  `LocalMLXModelViewModel` against a `MockLocalMLXModelEngine`, so none of it
//  touches a real Hub download or the GPU. `prepare(_:)` returns its in-flight
//  task, so tests await completion instead of polling.
//

import Foundation
import Testing
@testable import VivaDicta

@MainActor
struct LocalMLXModelViewModelTests {

    private func isFailed(_ status: LocalMLXModelViewModel.Status) -> Bool {
        if case .failed = status { return true }
        return false
    }

    private func isDownloading(_ status: LocalMLXModelViewModel.Status) -> Bool {
        if case .downloading = status { return true }
        return false
    }

    private struct StubError: Error {}

    // MARK: - prepare: happy path

    @Test func prepare_success_setsReadyAndRecordsSize() async {
        let mock = MockLocalMLXModelEngine(bytesAfterDownload: 1_300_000_000)
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.prepare(.qwen35_2B).value

        #expect(sut.status(for: .qwen35_2B) == .ready)
        #expect(sut.sizeBytes[.qwen35_2B] == 1_300_000_000)
        #expect(await mock.ensureLoadedCalls == [.qwen35_2B])
    }

    @Test func prepare_withProgress_stillEndsReady() async {
        let mock = MockLocalMLXModelEngine(progressSequence: [0.25, 0.5, 1.0])
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.prepare(.qwen35_2B).value

        #expect(sut.status(for: .qwen35_2B) == .ready)
    }

    // MARK: - prepare: failures

    @Test func prepare_genericFailure_setsFailed() async {
        let mock = MockLocalMLXModelEngine(ensureLoadedError: StubError())
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.prepare(.qwen35_2B).value

        let status = sut.status(for: .qwen35_2B)
        #expect(isFailed(status), "Expected .failed, got \(status)")
    }

    @Test func prepare_cancellationError_setsNotDownloaded() async {
        let mock = MockLocalMLXModelEngine(ensureLoadedError: CancellationError())
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.prepare(.qwen35_2B).value

        #expect(sut.status(for: .qwen35_2B) == .notDownloaded)
    }

    @Test func prepare_urlCancelledError_setsNotDownloaded() async {
        let mock = MockLocalMLXModelEngine(ensureLoadedError: URLError(.cancelled))
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.prepare(.qwen35_2B).value

        #expect(sut.status(for: .qwen35_2B) == .notDownloaded)
    }

    // MARK: - cancel

    @Test func cancel_inFlightDownload_setsNotDownloaded() async {
        let mock = MockLocalMLXModelEngine(blockUntilCancelled: true)
        let sut = LocalMLXModelViewModel(engine: mock)

        let task = sut.prepare(.qwen35_2B)
        sut.cancel(.qwen35_2B)
        await task.value

        #expect(sut.status(for: .qwen35_2B) == .notDownloaded)
    }

    // MARK: - isDownloading (the global download lock)

    @Test func isDownloading_trueWhileInFlight_falseAfter() async {
        let mock = MockLocalMLXModelEngine(blockUntilCancelled: true)
        let sut = LocalMLXModelViewModel(engine: mock)

        let task = sut.prepare(.qwen35_2B)
        #expect(sut.isDownloading)

        sut.cancel(.qwen35_2B)
        await task.value
        #expect(!sut.isDownloading)
    }

    // MARK: - refresh

    @Test func refresh_downloadedModel_setsReadyWithSize() async {
        let mock = MockLocalMLXModelEngine(downloaded: [.qwen35_2B], bytes: [.qwen35_2B: 1_234])
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.refresh()

        #expect(sut.status(for: .qwen35_2B) == .ready)
        #expect(sut.sizeBytes[.qwen35_2B] == 1_234)
    }

    @Test func refresh_notDownloadedModel_setsNotDownloaded() async {
        let mock = MockLocalMLXModelEngine(downloaded: [])
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.refresh()

        #expect(sut.status(for: .llama32_3B) == .notDownloaded)
    }

    @Test func refresh_doesNotClobberInFlightDownload() async {
        let mock = MockLocalMLXModelEngine(blockUntilCancelled: true)
        let sut = LocalMLXModelViewModel(engine: mock)

        let task = sut.prepare(.qwen35_2B) // -> .downloading(0), blocks
        await sut.refresh()                // must skip the in-flight model

        let status = sut.status(for: .qwen35_2B)
        #expect(isDownloading(status), "Expected .downloading (in-flight), got \(status)")

        sut.cancel(.qwen35_2B)
        await task.value
    }

    // MARK: - delete

    @Test func delete_downloadedModel_setsNotDownloadedAndZeroSize() async {
        let mock = MockLocalMLXModelEngine(downloaded: [.qwen35_2B], bytes: [.qwen35_2B: 1_300_000_000])
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.delete(.qwen35_2B)

        #expect(sut.status(for: .qwen35_2B) == .notDownloaded)
        #expect(sut.sizeBytes[.qwen35_2B] == 0)
        #expect(await mock.deleteCalls == [.qwen35_2B])
    }

    @Test func delete_failure_setsFailed() async {
        let mock = MockLocalMLXModelEngine(downloaded: [.qwen35_2B], deleteError: StubError())
        let sut = LocalMLXModelViewModel(engine: mock)

        await sut.delete(.qwen35_2B)

        let status = sut.status(for: .qwen35_2B)
        #expect(isFailed(status), "Expected .failed, got \(status)")
    }
}
