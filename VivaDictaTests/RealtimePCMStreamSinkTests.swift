// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation
import Testing
@testable import VivaDicta

/// Covers the conversion the keyboard's hot-mic path needs: the prewarmed
/// engine taps in its native format (typically 48 kHz float32), while every
/// realtime socket wants `pcm_s16le` @ 16 kHz mono. The file written alongside
/// keeps the native format, so this sink is the only thing doing the
/// resampling - if it is wrong, the socket transcribes noise.
struct RealtimePCMStreamSinkTests {

    // MARK: - Helpers

    private func makeSink(
        inputSampleRate: Double = 48_000,
        channels: AVAudioChannelCount = 1
    ) -> (sink: RealtimePCMStreamSink, stream: AsyncStream<Data>)? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: inputSampleRate, channels: channels) else {
            return nil
        }
        var continuation: AsyncStream<Data>.Continuation!
        let stream = AsyncStream<Data> { continuation = $0 }
        guard let sink = RealtimePCMStreamSink(inputFormat: format, continuation: continuation) else {
            return nil
        }
        return (sink, stream)
    }

    /// A buffer of `frames` at `sampleRate`, filled with a 440 Hz tone so the
    /// resampled output carries real signal rather than silence.
    private func makeToneBuffer(sampleRate: Double, frames: AVAudioFrameCount, channels: AVAudioChannelCount = 1) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames

        let channelData = try #require(buffer.floatChannelData)
        for channel in 0..<Int(channels) {
            for frame in 0..<Int(frames) {
                let phase = 2 * Float.pi * 440 * Float(frame) / Float(sampleRate)
                channelData[channel][frame] = 0.5 * sin(phase)
            }
        }
        return buffer
    }

    /// Drains everything yielded before the stream finished.
    private func collect(_ stream: AsyncStream<Data>) async -> [Data] {
        var chunks: [Data] = []
        for await chunk in stream {
            chunks.append(chunk)
        }
        return chunks
    }

    // MARK: - Conversion

    /// `AVAudioConverter` consumes at most 4,096 input frames per `convert`
    /// call, so a single larger buffer emits only part of its audio and keeps
    /// the rest for the next call. Nothing is lost - it just cannot be asserted
    /// one chunk at a time, which is why these sum across a run of buffers the
    /// size the engine actually delivers.
    private func totalFrames(
        inputSampleRate: Double,
        channels: AVAudioChannelCount = 1,
        framesPerBuffer: AVAudioFrameCount,
        buffers: Int
    ) async throws -> Int {
        let (sut, stream) = try #require(makeSink(inputSampleRate: inputSampleRate, channels: channels))
        for _ in 0..<buffers {
            sut.process(try makeToneBuffer(sampleRate: inputSampleRate, frames: framesPerBuffer, channels: channels))
        }
        sut.finish()
        return await collect(stream).reduce(0) { $0 + $1.count / 2 }
    }

    @Test func downsamplesToSixteenKilohertzMonoInt16() async throws {
        // 4,096 frames is what `StreamingAudioCapture` installs its tap with.
        let frames = try await totalFrames(inputSampleRate: 48_000, framesPerBuffer: 4_096, buffers: 10)

        let ideal = 10 * 4_096 / 3
        #expect(abs(frames - ideal) < ideal / 100, "expected ~\(ideal) frames at 16 kHz, got \(frames)")
    }

    // The prewarmed engine installs its tap at 1,024 - the smaller of the two
    // sizes, and the one the keyboard path runs on.
    @Test func downsamplesAtThePrewarmTapBufferSize() async throws {
        let frames = try await totalFrames(inputSampleRate: 48_000, framesPerBuffer: 1_024, buffers: 20)

        let ideal = 20 * 1_024 / 3
        #expect(abs(frames - ideal) < ideal / 100, "expected ~\(ideal) frames at 16 kHz, got \(frames)")
    }

    // The engine hands out whatever the hardware runs at; 44.1 kHz is the other
    // rate seen in the wild and does not divide evenly into 16 kHz.
    @Test func handlesANonIntegerResamplingRatio() async throws {
        let frames = try await totalFrames(inputSampleRate: 44_100, framesPerBuffer: 4_096, buffers: 10)

        let ideal = Int((Double(10 * 4_096) * 16_000 / 44_100).rounded())
        #expect(abs(frames - ideal) < ideal / 100, "expected ~\(ideal) frames at 16 kHz, got \(frames)")
    }

    @Test func mixesStereoInputDownToMono() async throws {
        let frames = try await totalFrames(inputSampleRate: 48_000, channels: 2, framesPerBuffer: 4_096, buffers: 10)

        // One channel out, not two - a stereo passthrough would double this.
        let ideal = 10 * 4_096 / 3
        #expect(abs(frames - ideal) < ideal / 100, "expected ~\(ideal) mono frames, got \(frames)")
    }

    @Test func everyChunkIsWholeInt16Samples() async throws {
        let (sut, stream) = try #require(makeSink())
        for _ in 0..<3 {
            sut.process(try makeToneBuffer(sampleRate: 48_000, frames: 4_096))
        }
        sut.finish()

        let chunks = await collect(stream)
        #expect(!chunks.isEmpty)
        #expect(chunks.allSatisfy { !$0.isEmpty && $0.count % 2 == 0 })
    }

    // MARK: - Lifecycle

    @Test func finishTerminatesTheStream() async throws {
        let (sut, stream) = try #require(makeSink())
        sut.finish()

        let chunks = await collect(stream)
        #expect(chunks.isEmpty)
    }

    // `stopRealCapture()` and `endSession()` can both land on the same sink.
    @Test func finishIsIdempotent() async throws {
        let (sut, stream) = try #require(makeSink())
        sut.finish()
        sut.finish()

        let chunks = await collect(stream)
        #expect(chunks.isEmpty)
    }

    // The tap can still be mid-callback when the capture is torn down; a yield
    // landing after the stream closed must be dropped, not crash.
    @Test func processAfterFinishIsIgnored() async throws {
        let (sut, stream) = try #require(makeSink())
        sut.finish()
        sut.process(try makeToneBuffer(sampleRate: 48_000, frames: 4_800))

        let chunks = await collect(stream)
        #expect(chunks.isEmpty)
    }

    @Test func matchesTheSampleRateStreamingCaptureUses() {
        // The two capture paths feed the same sockets, so they must agree.
        #expect(RealtimePCMStreamSink.sampleRate == StreamingAudioCapture.sampleRate)
    }
}
