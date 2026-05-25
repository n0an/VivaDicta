// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation
import Testing
@testable import AudioRecording
import AudioRecordingMocks

struct DefaultAudioFileServiceTests {

    let sut = DefaultAudioFileService()

    @Test func move_transfersFileToDestination() throws {
        let source = try makeTempFile(contents: Data([1, 2, 3]))
        let destination = uniqueTempURL()

        try sut.move(from: source, to: destination)

        #expect(FileManager.default.fileExists(atPath: source.path) == false)
        #expect(FileManager.default.fileExists(atPath: destination.path))
        try FileManager.default.removeItem(at: destination)
    }

    @Test func move_throwsWhenSourceMissing() {
        let missingSource = uniqueTempURL()
        let destination = uniqueTempURL()

        #expect(throws: (any Error).self) {
            try sut.move(from: missingSource, to: destination)
        }
    }

    @Test func remove_deletesFile() throws {
        let url = try makeTempFile(contents: Data([0xff]))

        try sut.remove(at: url)

        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test func remove_throwsWhenFileMissing() {
        let missing = uniqueTempURL()

        #expect(throws: (any Error).self) {
            try sut.remove(at: missing)
        }
    }

    @Test func fileSize_returnsBytesOnDisk() throws {
        let payload = Data(repeating: 0xab, count: 512)
        let url = try makeTempFile(contents: payload)
        defer { try? FileManager.default.removeItem(at: url) }

        let size = try sut.fileSize(at: url)

        #expect(size == 512)
    }

    @Test func duration_returnsSecondsOfGeneratedWav() async throws {
        let source = try makeSineWaveFile(sampleRate: 44_100, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: source) }

        let duration = try await sut.duration(of: source)

        // AVAsset duration can drift a few ms; allow 50ms tolerance.
        #expect(abs(duration - 0.5) < 0.05)
    }

    @Test func downsampleTo16kHzMono_producesValidShorterRateFile() async throws {
        let source = try makeSineWaveFile(sampleRate: 44_100, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: source) }
        let destination = source.deletingPathExtension().appendingPathExtension("16k.wav")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await sut.downsampleTo16kHzMono(from: source, to: destination)

        #expect(FileManager.default.fileExists(atPath: destination.path))

        let outFile = try AVAudioFile(forReading: destination)
        #expect(outFile.fileFormat.sampleRate == 16_000)
        #expect(outFile.fileFormat.channelCount == 1)
        #expect(outFile.length > 0)
    }
}

struct DefaultAudioRecordingServiceTests {

    // Recording itself can't be unit-tested - it needs microphone permission
    // and real audio hardware. The protocol is what consumers test against
    // via MockAudioRecordingService. Here we only assert the trivial
    // invariants of a fresh instance.

    @MainActor
    @Test func freshInstance_reportsIdleState() {
        let sut = DefaultAudioRecordingService()

        #expect(sut.isRecording == false)
        #expect(sut.currentTime == 0)
        #expect(sut.currentAudioPower == -160)
    }

    @MainActor
    @Test func unsuccessfulFinishCallback_canBeWiredAndCleared() {
        let sut = DefaultAudioRecordingService()
        sut.onDidFinishUnsuccessfully = {}

        #expect(sut.onDidFinishUnsuccessfully != nil)
        sut.onDidFinishUnsuccessfully = nil
        #expect(sut.onDidFinishUnsuccessfully == nil)
    }

    @MainActor
    @Test func mockUnsuccessfulFinishCallback_invokesConsumer() {
        let sut = MockAudioRecordingService()
        var fired = false
        sut.onDidFinishUnsuccessfully = { fired = true }

        sut.fireDidFinishUnsuccessfully()

        #expect(fired)
    }

    @MainActor
    @Test func stopRecording_returnsNilWhenNothingActive() {
        let sut = DefaultAudioRecordingService()

        #expect(sut.stopRecording() == nil)
    }
}

// MARK: - Helpers

private func uniqueTempURL(extension ext: String = "bin") -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
}

private func makeTempFile(contents: Data) throws -> URL {
    let url = uniqueTempURL()
    try contents.write(to: url)
    return url
}

/// Generate a short PCM Float32 WAV containing a 440 Hz sine wave. Used as
/// real audio input so duration / downsample tests exercise actual decoding
/// rather than relying on a fixture file checked into the repo.
private func makeSineWaveFile(sampleRate: Double, durationSeconds: Double) throws -> URL {
    guard let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    ) else {
        struct FormatError: Error {}
        throw FormatError()
    }

    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        struct BufferError: Error {}
        throw BufferError()
    }
    buffer.frameLength = frameCount

    let channel = buffer.floatChannelData![0]
    let twoPiF = 2.0 * .pi * 440.0
    for frame in 0..<Int(frameCount) {
        channel[frame] = Float(sin(twoPiF * Double(frame) / sampleRate)) * 0.25
    }

    let url = uniqueTempURL(extension: "wav")
    let outFile = try AVAudioFile(forWriting: url, settings: format.settings)
    try outFile.write(from: buffer)
    return url
}
