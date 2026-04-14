//
//  ParakeetTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.27
//

import AVFoundation
import Foundation
@preconcurrency import FluidAudio
import os

class ParakeetTranscriptionService: TranscriptionService {
    private var asrManager: AsrManager?
    private var vadManager: VadManager?
    private let logger = Logger(category: .parakeetTranscriptionService)

    init() {}

    func loadModel(model: ParakeetModel) async throws {
        guard asrManager == nil else {
            return
        }

        do {
            // Validate models before loading
            let isValid = try await AsrModels.isModelValid(version: model.version)
            if !isValid {
                logger.error("Model validation failed for \(model.version == .v2 ? "v2" : "v3"). Models are corrupted.")
                throw ParakeetTranscriptionError.modelValidationFailed("Parakeet models are corrupted. Please delete and re-download the model.")
            }

            let manager = AsrManager(config: .default)
            // Load from FluidAudio's default cache directory
            let models = try await AsrModels.loadFromCache(configuration: nil, version: model.version)
            try await manager.loadModels(models)

            self.asrManager = manager
            logger.logNotice("✅ Parakeet ASR model loaded successfully")
        } catch {
            logger.logError("❌ Failed to load Parakeet model: \(error.localizedDescription)")
            throw error
        }
    }
 
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> TranscriptionServiceResult {
        guard let parakeetModel = model as? ParakeetModel else {
            throw TranscriptionError.unsupportedModel
        }
        
        try await loadModel(model: parakeetModel)
        
        guard let asrManager = asrManager else {
            logger.logNotice("🦜 ASR manager not initialized, cannot transcribe")
            throw TranscriptionError.modelLoadFailed
        }
        
        logger.logNotice("🦜 Starting Parakeet transcription with model: \(parakeetModel.displayName)")

        let audioFile = try AVAudioFile(forReading: audioURL)
        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        logger.logNotice("📊 Audio duration: \(durationSeconds.formatted(.number.precision(.fractionLength(2)))) seconds")

        // Apply VAD for recordings longer than 20 seconds
        // VAD setting should be shared with keyboard extension
        let isVADEnabled = UserDefaultsStorage.shared.object(forKey: AppGroupCoordinator.kIsVADEnabled) as? Bool ?? true

        if durationSeconds < 20.0 || !isVADEnabled {
            logger.logNotice("🎙️ Using direct file transcription for Parakeet")
            let result = try await asrManager.transcribe(audioURL, source: .system)

            await asrManager.cleanup()
            self.asrManager = nil
            self.vadManager = nil
            logger.logNotice("🦜 Parakeet ASR models cleaned up from memory")
            logger.logNotice("✅ Parakeet transcription completed successfully")
            return result.text
        }

        logger.logNotice("🎙️ Applying VAD for long audio (> 20s)")

        // VAD segmentation still requires 16kHz mono Float32 samples.
        var speechAudio = try await readAndConvertAudio(from: audioURL)
        speechAudio = try await applyVAD(to: speechAudio)

        // Add trailing silence to improve final word punctuation detection
        let trailingSilenceSamples = 16_000 // 1 second at 16kHz
        let maxSingleChunkSamples = 240_000
        if speechAudio.count + trailingSilenceSamples <= maxSingleChunkSamples {
            speechAudio += [Float](repeating: 0, count: trailingSilenceSamples)
        }

        // Transcribe the audio
        let result = try await asrManager.transcribe(speechAudio, source: .system)

        // Clean up models after transcription to minimize RAM usage
        await asrManager.cleanup()
        
        self.asrManager = nil
        self.vadManager = nil
        logger.logNotice("🦜 Parakeet ASR models cleaned up from memory")
        
        logger.logNotice("✅ Parakeet transcription completed successfully")
        return .plain(result.text)
    }

    private func readAndConvertAudio(from url: URL) async throws -> [Float] {
        // Use AudioConverter from FluidAudio to properly convert audio to 16kHz mono
        let converter = AudioConverter()
        return try converter.resampleAudioFile(path: url.path)
    }

    private func applyVAD(to audioSamples: [Float]) async throws -> [Float] {
        let vadConfig = VadConfig(defaultThreshold: 0.7)

        // Initialize VAD manager if needed (uses FluidAudio's default cache)
        if vadManager == nil {
            do {
                vadManager = try await VadManager(config: vadConfig)
            } catch {
                logger.logWarning("⚠️ VAD init failed, falling back to full audio: \(error.localizedDescription)")
                return audioSamples
            }
        }

        guard let vadManager = vadManager else {
            logger.logWarning("⚠️ VAD manager not available, using full audio")
            return audioSamples
        }

        do {
            // Segment speech using VAD
            let segments = try await vadManager.segmentSpeechAudio(audioSamples)

            if segments.isEmpty {
                logger.logWarning("⚠️ VAD found no speech segments, using full audio")
                return audioSamples
            }

            // Concatenate all speech segments
            let totalSamples = segments.reduce(0) { $0 + $1.count }
            logger.logNotice("📊 VAD extracted \(segments.count) segments, total: \((Double(totalSamples) / 16000.0).formatted(.number.precision(.fractionLength(2))))s")

            return segments.flatMap { $0 }
        } catch {
            logger.logWarning("⚠️ VAD processing failed: \(error.localizedDescription), using full audio")
            return audioSamples
        }
    }
}

enum ParakeetTranscriptionError: LocalizedError {
    case modelValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelValidationFailed(let message):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .modelValidationFailed:
            return "Parakeet model validation failed"
        }
    }
}
