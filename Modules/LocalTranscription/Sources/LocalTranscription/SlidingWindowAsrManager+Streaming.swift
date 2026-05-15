// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
@preconcurrency import FluidAudio
import TranscriptionCore

extension SlidingWindowAsrManager {
    /// Streams a buffer of 16 kHz mono float samples to the sliding-window ASR
    /// manager by wrapping them in an `AVAudioPCMBuffer` first.
    func streamFloatSamples(_ audioSamples: [Float]) throws {
        guard !audioSamples.isEmpty else { return }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw TranscriptionError.audioConversionFailed
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioSamples.count)
        ) else {
            throw TranscriptionError.audioConversionFailed
        }

        buffer.frameLength = AVAudioFrameCount(audioSamples.count)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw TranscriptionError.audioConversionFailed
        }

        audioSamples.withUnsafeBufferPointer { samplesPointer in
            channelData.update(from: samplesPointer.baseAddress!, count: audioSamples.count)
        }

        streamAudio(buffer)
    }
}
