// Copyright © 2026 Anton Novoselov. All rights reserved.

@preconcurrency import AVFoundation
import Foundation

/// Production `AudioFileService` built on `FileManager` and
/// `AVAudioConverter`. Stateless; safe to instantiate per call.
public struct DefaultAudioFileService: AudioFileService {

    public init() {}

    public func move(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
    }

    public func remove(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? Int64) ?? 0
    }

    public func duration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    public func downsampleTo16kHzMono(from source: URL, to destination: URL) async throws {
        let inFile = try AVAudioFile(forReading: source)
        let inFmt = inFile.processingFormat

        guard let outFmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioFileError.unsupportedFormat
        }

        guard let converter = AVAudioConverter(from: inFmt, to: outFmt) else {
            throw AudioFileError.converterUnavailable
        }
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue

        let frameCount = AVAudioFrameCount(inFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: frameCount) else {
            throw AudioFileError.bufferAllocationFailed
        }
        try inFile.read(into: inputBuffer)

        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * (16_000.0 / inFmt.sampleRate))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: outputFrameCount) else {
            throw AudioFileError.bufferAllocationFailed
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        if let error {
            throw error
        }

        let outFile = try AVAudioFile(
            forWriting: destination,
            settings: outFmt.settings,
            commonFormat: outFmt.commonFormat,
            interleaved: false
        )
        try outFile.write(from: outputBuffer)
    }
}

public enum AudioFileError: Error {
    case unsupportedFormat
    case converterUnavailable
    case bufferAllocationFailed
}
