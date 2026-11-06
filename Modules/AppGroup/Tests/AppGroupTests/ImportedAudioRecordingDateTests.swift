//
//  ImportedAudioRecordingDateTests.swift
//  AppGroupTests
//
//  Created by Anton Novoselov on 2026.11.06
//

import AVFoundation
import Foundation
import Testing
@testable import AppGroup

struct ImportedAudioRecordingDateTests {
    private let importedAt = Date(timeIntervalSince1970: 1_793_000_000)

    // MARK: - Trust rule

    @Test func dateWellBeforeImport_isTrusted() {
        let recorded = importedAt.addingTimeInterval(-3 * 3600)
        #expect(ImportedAudioRecordingDate.isTrustworthy(recorded, importedAt: importedAt))
    }

    @Test(arguments: [0.0, -1, -59, 30, 86_400])
    func dateAtOrNearImport_isNotTrusted(offset: TimeInterval) {
        let candidate = importedAt.addingTimeInterval(offset)
        #expect(!ImportedAudioRecordingDate.isTrustworthy(candidate, importedAt: importedAt))
    }

    @Test(arguments: [
        Date(timeIntervalSince1970: 0),                 // Unix epoch
        Date(timeIntervalSince1970: -2_082_844_800),    // QuickTime 1904 epoch
    ])
    func zeroedHeaderDate_isNotTrusted(date: Date) {
        #expect(!ImportedAudioRecordingDate.isTrustworthy(date, importedAt: importedAt))
    }

    // MARK: - Source order

    @Test func mediaDate_winsOverFileDate() {
        let media = importedAt.addingTimeInterval(-7200)
        let file = importedAt.addingTimeInterval(-3600)
        let result = ImportedAudioRecordingDate.resolve(mediaCreationDates: [media], fileCreationDate: file, importedAt: importedAt)
        #expect(result == media)
    }

    @Test func untrustedMediaDate_fallsBackToFileDate() {
        let file = importedAt.addingTimeInterval(-3600)
        let result = ImportedAudioRecordingDate.resolve(mediaCreationDates: [importedAt], fileCreationDate: file, importedAt: importedAt)
        #expect(result == file)
    }

    @Test func noTrustworthySource_isNil() {
        #expect(ImportedAudioRecordingDate.resolve(mediaCreationDates: [], fileCreationDate: nil, importedAt: importedAt) == nil)
        #expect(ImportedAudioRecordingDate.resolve(
            mediaCreationDates: [importedAt.addingTimeInterval(-10)],
            fileCreationDate: importedAt,
            importedAt: importedAt
        ) == nil)
    }

    // MARK: - Real files

    @Test func fileCreationDate_isReadFromAFileWithoutMediaMetadata() async throws {
        let url = try makeTemporaryFile(extension: "bin")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorded = Date().addingTimeInterval(-2 * 86_400).rounded()
        try FileManager.default.setAttributes([.creationDate: recorded], ofItemAtPath: url.path)

        let result = await ImportedAudioRecordingDate.read(from: url)

        #expect(result == recorded)
    }

    @Test func freshlyCreatedFile_hasNoTrustworthyDate() async throws {
        let url = try makeTemporaryFile(extension: "bin")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(await ImportedAudioRecordingDate.read(from: url) == nil)
    }

    @Test func secondTrustworthyMediaDate_isUsedWhenTheFirstIsTheImportTime() {
        let recorded = importedAt.addingTimeInterval(-5400)
        let result = ImportedAudioRecordingDate.resolve(
            mediaCreationDates: [importedAt.addingTimeInterval(-2), recorded],
            fileCreationDate: importedAt,
            importedAt: importedAt
        )
        #expect(result == recorded)
    }

    /// Recorded Monday, exported Tuesday, imported Wednesday: both dates pass
    /// the trust check, and the recorder's date must win.
    @Test func recorderKey_winsOverAnOlderExportDateOfTheContainer() {
        let monday = importedAt.addingTimeInterval(-2 * 86_400)
        let tuesday = importedAt.addingTimeInterval(-86_400)
        let dates = ImportedAudioRecordingDate.ordered(recorderDates: [monday], containerDate: tuesday, dayDates: [])

        #expect(dates == [monday, tuesday])
        #expect(ImportedAudioRecordingDate.resolve(mediaCreationDates: dates, fileCreationDate: tuesday, importedAt: importedAt) == monday)
    }

    @Test func dayKey_ranksAfterTheContainerDate_andDuplicatesAreDropped() {
        let container = importedAt.addingTimeInterval(-3600)
        let release = importedAt.addingTimeInterval(-400 * 86_400)
        let dates = ImportedAudioRecordingDate.ordered(recorderDates: [container], containerDate: container, dayDates: [release])

        #expect(dates == [container, release])
    }

    /// A re-exported file: the container's own creation time is the export
    /// moment, and the recorder's date survives only in a metadata key.
    @Test(arguments: [MetadataKey.quickTimeCreationDate, .commonCreationDate])
    func recorderDate_isReadFromTheAudioFile(key: MetadataKey) async throws {
        guard #available(macOS 15, iOS 18, *) else { return }
        let recorded = Date().addingTimeInterval(-26 * 3600).rounded()
        let url = try await makeM4A(creationDate: recorded, key: key)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(await ImportedAudioRecordingDate.mediaCreationDates(of: url).contains(recorded))
        // The file itself was just written, so only the recorder's date can be trusted.
        #expect(await ImportedAudioRecordingDate.read(from: url) == recorded)
    }

    @Test func dayOnlyMetadata_isNotARecordingTime() async throws {
        guard #available(macOS 15, iOS 18, *) else { return }
        let url = try await makeM4A(rawValue: "2019-05-04", key: .quickTimeCreationDate)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(await ImportedAudioRecordingDate.read(from: url) == nil)
    }

    // MARK: - Helpers

    private func makeTemporaryFile(extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(ext)")
        try Data([0, 1, 2, 3]).write(to: url)
        return url
    }

    enum MetadataKey: Sendable {
        case quickTimeCreationDate
        case commonCreationDate
    }

    @available(macOS 15, iOS 18, *)
    private func makeM4A(creationDate: Date, key: MetadataKey) async throws -> URL {
        try await makeM4A(rawValue: creationDate.formatted(.iso8601), key: key)
    }

    /// Writes one second of silence as .m4a with a creation date metadata item.
    @available(macOS 15, iOS 18, *)
    private func makeM4A(rawValue: String, key: MetadataKey) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        let cafURL = directory.appending(path: "\(UUID().uuidString).caf")
        let m4aURL = directory.appending(path: "\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: cafURL) }

        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000))
        buffer.frameLength = 16_000
        do {
            let file = try AVAudioFile(forWriting: cafURL, settings: format.settings)
            try file.write(from: buffer)
        }

        let exporter = try #require(AVAssetExportSession(asset: AVURLAsset(url: cafURL), presetName: AVAssetExportPresetAppleM4A))
        let item = AVMutableMetadataItem()
        switch key {
        case .quickTimeCreationDate:
            item.keySpace = .quickTimeMetadata
            item.key = AVMetadataKey.quickTimeMetadataKeyCreationDate as NSString
        case .commonCreationDate:
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyCreationDate as NSString
        }
        item.value = rawValue as NSString
        exporter.metadata = [item]
        try await exporter.export(to: m4aURL, as: .m4a)
        return m4aURL
    }
}

private extension Date {
    /// Whole seconds, matching what file systems and ISO 8601 strings keep.
    func rounded() -> Date {
        Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down))
    }
}
