//
//  SlidingWindowAsrManager+VivaDicta.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import AVFoundation
@preconcurrency import FluidAudio

extension SlidingWindowAsrManager {
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
