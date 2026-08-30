// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation

/// Converts an engine tap's native buffers into the PCM the realtime sockets
/// take, and yields them into an `AsyncStream`.
///
/// This exists for the prewarmed (hot mic) capture path, which writes its WAV in
/// the engine's *native* format - whatever the input node hands out, often 48 kHz
/// float32 - because that is what the keyboard flow has always recorded and what
/// the upload fallback already handles. The socket needs `pcm_s16le` @ 16 kHz
/// mono, so the conversion happens here, for the stream only, leaving the file
/// untouched.
///
/// `StreamingAudioCapture.CaptureSink` deliberately does not use this: it
/// converts once and writes the *converted* buffer to both the file and the
/// socket, so routing its yield through here would convert twice on the audio
/// thread. Two call sites, two different tradeoffs.
///
/// Every method runs on AVAudioEngine's realtime thread.
nonisolated final class RealtimePCMStreamSink: @unchecked Sendable {
    /// What every realtime provider is configured for - see
    /// `StreamingAudioCapture.sampleRate`, which must stay in step.
    static let sampleRate: Double = 16_000

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let continuation: AsyncStream<Data>.Continuation

    /// Fails when the input format is unusable or the converter cannot be built,
    /// so the caller can fall back to a non-streaming capture rather than
    /// opening a socket that will never be fed.
    init?(inputFormat: AVAudioFormat, continuation: AsyncStream<Data>.Continuation) {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { return nil }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: true
        ) else { return nil }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }

        self.converter = converter
        self.outputFormat = outputFormat
        self.continuation = continuation
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrames = Double(buffer.frameLength) * ratio
        let capacity = AVAudioFrameCount(estimatedFrames.rounded(.up)) + 1024

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var providedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { _, statusPtr in
            if providedInput {
                statusPtr.pointee = .noDataNow
                return nil
            }
            providedInput = true
            statusPtr.pointee = .haveData
            return buffer
        }

        guard status != .error, conversionError == nil else { return }
        guard outBuffer.frameLength > 0, let channelData = outBuffer.int16ChannelData else { return }

        continuation.yield(Data(bytes: channelData[0], count: Int(outBuffer.frameLength) * 2))
    }

    /// Closes the stream so the pump feeding the socket drains and exits.
    /// `AsyncStream.Continuation.finish()` is idempotent, so a second call from
    /// a teardown path is harmless.
    func finish() {
        continuation.finish()
    }
}
