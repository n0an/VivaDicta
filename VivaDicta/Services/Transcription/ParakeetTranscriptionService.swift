//
//  ParakeetTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.27
//

import Foundation
import FluidAudio
import os

class ParakeetTranscriptionService: TranscriptionService {
    private var asrManager: AsrManager?
    private var vadManager: VadManager?
    private var isModelLoaded = false
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "ParakeetTranscriptionService")

    init() {}

    func loadModel(modelsDirectory: URL) async throws {
        if isModelLoaded {
            return
        }

        do {
            asrManager = AsrManager(config: .default)
            let models = try await AsrModels.load(from: modelsDirectory)
            try await asrManager?.initialize(models: models)
            isModelLoaded = true
            logger.notice("✅ Parakeet ASR model loaded successfully")
        } catch {
            isModelLoaded = false
            asrManager = nil
            logger.error("❌ Failed to load Parakeet model: \(error.localizedDescription)")
            throw error
        }
    }
 
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let parakeetModel = model as? ParakeetModel else {
            throw WhisperStateError.modelLoadFailed
        }
        
        if asrManager == nil || !isModelLoaded {
            try await loadModel(modelsDirectory: parakeetModel.modelsDirectory)
        }

        guard let asrManager = asrManager else {
            throw WhisperStateError.transcriptionFailed
        }

        logger.notice("🦜 Starting Parakeet transcription with model: \(parakeetModel.displayName)")

        // Read and convert audio to 16kHz mono Float32
        let audioSamples = try await readAndConvertAudio(from: audioURL)
        let durationSeconds = Double(audioSamples.count) / 16000.0

        logger.notice("📊 Audio duration: \(String(format: "%.2f", durationSeconds)) seconds")

        // Apply VAD for recordings longer than 20 seconds
        let isVADEnabled = UserDefaults.standard.object(forKey: "IsVADEnabled") as? Bool ?? true
        
        let speechAudio: [Float]
        
        if durationSeconds < 20.0 || !isVADEnabled {
            speechAudio = audioSamples
        } else {
            logger.notice("🎙️ Applying VAD for long audio (> 20s)")
            speechAudio = try await applyVAD(to: audioSamples, modelsDirectory: parakeetModel.modelsDirectory)
        }
        
        // Transcribe the audio
        let result = try await asrManager.transcribe(speechAudio)

        // Clean up models after transcription to minimize RAM usage
        Task {
            asrManager.cleanup()
            vadManager = nil
            isModelLoaded = false
            logger.notice("🧹 Parakeet ASR models cleaned up from memory")
        }

        logger.notice("✅ Parakeet transcription completed successfully")
        return result.text
    }

    private func readAndConvertAudio(from url: URL) async throws -> [Float] {
        // Use AudioConverter from FluidAudio to properly convert audio to 16kHz mono
        let converter = AudioConverter()
        return try converter.resampleAudioFile(path: url.path)
    }

    private func applyVAD(to audioSamples: [Float], modelsDirectory: URL) async throws -> [Float] {
        let vadConfig = VadConfig(threshold: 0.7)

        // Initialize VAD manager if needed
        if vadManager == nil {
            // VAD models are stored in documents directory
            vadManager = try await VadManager(
                config: vadConfig,
                modelDirectory: URL.documentsDirectory
            )
        }

        guard let vadManager = vadManager else {
            logger.warning("⚠️ VAD manager initialization failed, using full audio")
            return audioSamples
        }

        do {
            // Segment speech using VAD
            let segments = try await vadManager.segmentSpeechAudio(audioSamples)

            if segments.isEmpty {
                logger.warning("⚠️ VAD found no speech segments, using full audio")
                return audioSamples
            }

            // Concatenate all speech segments
            let totalSamples = segments.reduce(0) { $0 + $1.count }
            logger.notice("📊 VAD extracted \(segments.count) segments, total: \(String(format: "%.2f", Double(totalSamples) / 16000.0))s")

            return segments.flatMap { $0 }
        } catch {
            logger.warning("⚠️ VAD processing failed: \(error.localizedDescription), using full audio")
            return audioSamples
        }
    }
}
