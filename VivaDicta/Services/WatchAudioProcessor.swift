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

    /// Tracks filenames currently being processed to avoid duplicates.
    private(set) var inFlightFiles: Set<String> = []


    init(transcriptionManager: TranscriptionManager,
         aiService: AIService,
         modelContainer: ModelContainer) {
        self.transcriptionManager = transcriptionManager
        self.aiService = aiService
        self.modelContainer = modelContainer
    }

    func processAudioFile(at audioURL: URL, sourceTag: String, recordingTimestamp: Date = Date(), modeId: String? = nil) async {
        let fileName = audioURL.lastPathComponent

        guard !inFlightFiles.contains(fileName) else {
            logger.logInfo("⌚ [SKIP] Already processing: \(fileName)")
            return
        }
        inFlightFiles.insert(fileName)
        defer { inFlightFiles.remove(fileName) }

        // Temporarily switch to the requested mode if specified
        let previousModeName = aiService.selectedModeName
        if let modeId,
           let targetMode = aiService.modes.first(where: { $0.id.uuidString == modeId }) {
            aiService.selectedModeName = targetMode.name
            transcriptionManager.setCurrentMode(targetMode)
        }
        defer {
            if modeId != nil {
                aiService.selectedModeName = previousModeName
                transcriptionManager.setCurrentMode(aiService.selectedMode)
            }
        }

        do {
            logger.logInfo("⌚ [START] Processing watch audio: \(audioURL.lastPathComponent)")

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
                    logger.logWarning("⌚ Watch audio AI enhancement failed: \(error.localizedDescription)")
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
            logger.logInfo("⌚ [DONE] Watch audio processed and saved: \(audioURL.lastPathComponent)")

        } catch {
            logger.logError("⌚ [FAILED] Watch audio processing failed: \(error.localizedDescription)")
        }
    }

    /// Checks for orphaned watch audio files that were never transcribed
    /// (e.g. if iOS killed the app during background processing).
    /// - Parameter excludedFileNames: Filenames to skip (e.g. files still in the background task queue).
    func processOrphanedFiles(excludedFileNames: Set<String> = []) async {
        let audioDir = FileManager.appDirectory(for: .audio)

        let fm = FileManager.default
        guard fm.fileExists(atPath: audioDir.path) else { return }

        guard let files = try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)
            .filter({ $0.lastPathComponent.hasPrefix("watch-") && $0.pathExtension == "wav" }) else { return }

        guard !files.isEmpty else { return }

        // Find which filenames already have a Transcription record
        let context = ModelContext(modelContainer)
        let existingFileNames: Set<String> = {
            let descriptor = FetchDescriptor<Transcription>()
            guard let transcriptions = try? context.fetch(descriptor) else { return [] }
            return Set(transcriptions.compactMap(\.audioFileName))
        }()

        let orphaned = files.filter {
            !existingFileNames.contains($0.lastPathComponent) &&
            !inFlightFiles.contains($0.lastPathComponent) &&
            !excludedFileNames.contains($0.lastPathComponent)
        }

        guard !orphaned.isEmpty else {
            logger.logInfo("⌚ [ORPHAN CHECK] No orphaned watch audio files found")
            return
        }
        logger.logInfo("⌚ [ORPHAN CHECK] Found \(orphaned.count) orphaned watch audio file(s), processing")

        for file in orphaned {
            await processAudioFile(at: file, sourceTag: SourceTag.appleWatch)
        }
    }
}
