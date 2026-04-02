//
//  WatchAudioProcessor.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.02
//

import Foundation
import SwiftData
import AVFoundation
import CoreMedia
import os

/// Processes audio files received from Apple Watch in the background.
///
/// Unlike `RecordViewModel.transcribeSpeechTask()`, this processor has no UI
/// dependencies and can run while the app is suspended. It reuses the existing
/// `TranscriptionManager` and `AIService` for transcription and enhancement.
@MainActor
final class WatchAudioProcessor {
    private let logger = Logger(category: .watchConnectivity)

    private let transcriptionManager: TranscriptionManager
    private let aiService: AIService
    private let modelContainer: ModelContainer

    init(transcriptionManager: TranscriptionManager,
         aiService: AIService,
         modelContainer: ModelContainer) {
        self.transcriptionManager = transcriptionManager
        self.aiService = aiService
        self.modelContainer = modelContainer
    }

    func processAudioFile(at audioURL: URL, sourceTag: String, recordingTimestamp: Date = Date()) async {
        do {
            logger.logInfo("Processing watch audio: \(audioURL.lastPathComponent)")

            // Transcribe
            let transcriptionStart = Date()
            let transcribedText = try await transcriptionManager.transcribe(audioURL: audioURL)
            let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

            // Validate
            guard TranscriptionOutputFilter.hasMeaningfulContent(transcribedText) else {
                logger.logInfo("Watch transcription has no meaningful content, skipping")
                try? FileManager.default.removeItem(at: audioURL)
                return
            }

            // Get audio duration
            let audioAsset = AVURLAsset(url: audioURL)
            let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

            // AI enhancement
            var enhancedText: String?
            var promptName: String?
            var enhancementDuration: TimeInterval?

            if aiService.isProperlyConfigured() {
                do {
                    let result = try await aiService.enhance(transcribedText)
                    enhancedText = result.0
                    enhancementDuration = result.1
                    promptName = result.2
                } catch {
                    logger.logWarning("Watch audio AI enhancement failed: \(error.localizedDescription)")
                }
            }

            // Save to SwiftData
            let context = ModelContext(modelContainer)

            let transcription = Transcription(
                text: transcribedText,
                enhancedText: enhancedText,
                audioDuration: audioDuration,
                audioFileName: audioURL.lastPathComponent,
                transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                transcriptionProviderName: transcriptionManager.currentMode.transcriptionProvider.displayName,
                aiEnhancementModelName: enhancedText != nil ? aiService.selectedMode.aiModel : nil,
                aiProviderName: enhancedText != nil ? aiService.selectedMode.aiProvider?.displayName : nil,
                promptName: promptName,
                transcriptionDuration: transcriptionDuration,
                enhancementDuration: enhancementDuration,
                powerModeId: aiService.selectedMode.id.uuidString,
                sourceTag: sourceTag
            )

            transcription.timestamp = recordingTimestamp
            context.insert(transcription)

            // Dual-write variation
            if let enhancedText {
                let variation = TranscriptionVariation(
                    presetId: aiService.selectedMode.presetId ?? "regular",
                    presetDisplayName: promptName ?? "Regular",
                    text: enhancedText,
                    aiModelName: aiService.selectedMode.aiModel,
                    aiProviderName: aiService.selectedMode.aiProvider?.displayName,
                    processingDuration: enhancementDuration,
                    aiRequestSystemMessage: aiService.lastSystemMessageSent,
                    aiRequestUserMessage: aiService.lastUserMessageSent
                )
                variation.transcription = transcription
                context.insert(variation)
            }

            try context.save()
            logger.logInfo("Watch audio processed and saved: \(audioURL.lastPathComponent)")

        } catch {
            logger.logError("Watch audio processing failed: \(error.localizedDescription)")
        }
    }
}
