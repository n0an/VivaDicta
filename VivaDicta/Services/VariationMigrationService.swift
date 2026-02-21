//
//  VariationMigrationService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import SwiftData
import os

/// Migrates existing `enhancedText` on transcriptions into `TranscriptionVariation` records.
///
/// This is a one-time migration that runs on first launch after the variation schema is introduced.
/// Each transcription with non-empty `enhancedText` gets a corresponding variation with
/// `presetId: "regular"`, preserving the AI model name, provider, and duration metadata.
class VariationMigrationService {
    static let shared = VariationMigrationService()
    private let logger = Logger(category: .variationMigration)
    private let migrationCompletedKey = "HasMigratedEnhancedTextToVariations_v1"

    private init() {}

    func migrateIfNeeded(context: ModelContext) {
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            return
        }

        logger.logInfo("Starting enhanced text migration to variations")

        var migrated = 0

        do {
            let descriptor = FetchDescriptor<Transcription>()
            let transcriptions = try context.fetch(descriptor)

            for transcription in transcriptions {
                guard let enhancedText = transcription.enhancedText,
                      !enhancedText.isEmpty else { continue }

                let variation = TranscriptionVariation()
                variation.presetId = "regular"
                variation.presetDisplayName = transcription.promptName ?? "Regular"
                variation.text = enhancedText
                variation.createdAt = transcription.timestamp
                variation.aiModelName = transcription.aiEnhancementModelName
                variation.aiProviderName = transcription.aiProviderName
                variation.processingDuration = transcription.enhancementDuration
                variation.transcription = transcription

                context.insert(variation)
                migrated += 1
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)
            logger.logInfo("Migrated \(migrated) enhanced texts to variations")
        } catch {
            logger.logError("Failed to migrate enhanced texts: \(error.localizedDescription)")
        }
    }
}
