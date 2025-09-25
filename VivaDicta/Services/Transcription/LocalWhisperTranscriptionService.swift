//
//  LocalWhisperTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import os
import whisper

class LocalTranscriptionService: TranscriptionService {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "LocalTranscriptionService")

    init() {}

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model.provider == .local else {
            throw WhisperStateError.modelLoadFailed
        }

        logger.notice("Initiating local transcription for model: \(model.displayName)")

        // Always create a new context for each transcription to minimize RAM usage
        // Find the model file on disk
        let availableModels = TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
        guard let localModel = availableModels.first(where: { $0.name == model.name }) else {
            logger.error("Model file not found for: \(model.name)")
            throw WhisperStateError.modelLoadFailed
        }

        let modelURL = localModel.fileURL
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            logger.error("Model file does not exist at path: \(modelURL.path)")
            throw WhisperStateError.modelLoadFailed
        }

        logger.notice("Loading model: \(model.name) from \(modelURL.path)")
        let whisperContext: WhisperContext
        do {
            whisperContext = try await WhisperContext.createContext(path: modelURL.path)
        } catch {
            logger.error("Failed to load model: \(model.name) - \(error.localizedDescription)")
            throw WhisperStateError.modelLoadFailed
        }

        // Read audio data
        let data = try readAudioSamples(audioURL)

        // Set prompt
        let currentPrompt = UserDefaults.standard.string(forKey: Constants.kTranscriptionPrompt) ?? ""
        await whisperContext.setPrompt(currentPrompt)

        // Transcribe
        let success = await whisperContext.fullTranscribe(samples: data)

        guard success else {
            logger.error("Core transcription engine failed (whisper_full).")
            throw WhisperStateError.whisperCoreFailed
        }

        let text = await whisperContext.getTranscription()

        logger.notice("✅ Local transcription completed successfully.")

        // Always release resources after transcription to minimize RAM usage
        await whisperContext.releaseResources()
        logger.notice("✅ Whisper context resources released.")

        return text
    }

    private func readAudioSamples(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            data[$0 ..< $0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }
}
