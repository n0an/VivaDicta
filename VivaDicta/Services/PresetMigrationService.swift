//
//  PresetMigrationService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import os

/// One-time migration from the legacy UserPrompt system to the new Preset system.
///
/// Handles:
/// - Matching existing UserPrompts to built-in presets by title
/// - Creating custom presets for unmatched UserPrompts
/// - Normalizing VivaMode presetIds from legacy title format to preset IDs
enum PresetMigrationService {
    private static let logger = Logger(category: .presetMigration)
    private static let migrationKey = "PresetMigration_v1_done"

    /// Title-to-preset-ID mapping for built-in templates.
    private static let titleToPresetId: [String: String] = [
        "regular": "regular",
        "email": "email",
        "chat": "chat",
        "coding": "coding",
        "vibe coding": "coding",
    ]

    /// Runs migration if not already completed.
    static func migrateIfNeeded(
        presetManager: PresetManager,
        aiService: AIService,
        userDefaults: UserDefaults = UserDefaultsStorage.shared
    ) {
        guard !userDefaults.bool(forKey: migrationKey) else { return }

        let promptsManager = PromptsManager(userDefaults: userDefaults)
        let userPrompts = promptsManager.userPrompts

        if userPrompts.isEmpty {
            logger.logInfo("No UserPrompts to migrate")
            userDefaults.set(true, forKey: migrationKey)
            return
        }

        logger.logInfo("Migrating \(userPrompts.count) UserPrompts to presets")

        // Build mapping: UserPrompt UUID → preset ID
        var promptIdToPresetId: [UUID: String] = [:]

        for prompt in userPrompts {
            let normalizedTitle = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if let builtInId = titleToPresetId[normalizedTitle] {
                // Matched to a built-in preset
                promptIdToPresetId[prompt.id] = builtInId

                // If user edited the instructions, update the built-in preset
                if let builtInDefault = PresetCatalog.defaultPreset(for: builtInId),
                   prompt.promptInstructions != builtInDefault.promptInstructions {
                    var edited = builtInDefault
                    edited.promptInstructions = prompt.promptInstructions
                    edited.isEdited = true
                    presetManager.updatePreset(edited)
                    logger.logInfo("Migrated edited built-in: '\(prompt.title)' → '\(builtInId)'")
                } else {
                    logger.logInfo("Migrated built-in: '\(prompt.title)' → '\(builtInId)'")
                }
            } else {
                // Custom prompt — create a new preset
                let customId = "custom_\(prompt.id.uuidString)"
                promptIdToPresetId[prompt.id] = customId

                let customPreset = Preset(
                    id: customId,
                    name: prompt.title,
                    icon: "text.bubble.fill",
                    category: "Other",
                    promptInstructions: prompt.promptInstructions,
                    useSystemTemplate: prompt.useSystemTemplate,
                    wrapInTranscriptTags: prompt.wrapInTranscriptTags,
                    isBuiltIn: false,
                    createdAt: prompt.createdAt
                )
                presetManager.addPreset(customPreset)
                logger.logInfo("Migrated custom: '\(prompt.title)' → '\(customId)'")
            }
        }

        // Normalize VivaMode presetIds
        // Old modes might have title-based presetIds from backward-compat decoding
        normalizeModePresetIds(aiService: aiService, promptMapping: promptIdToPresetId, userPrompts: userPrompts)

        userDefaults.set(true, forKey: migrationKey)
        logger.logInfo("Migration complete")
    }

    /// Normalizes presetIds in VivaModes from legacy title format to proper preset IDs.
    private static func normalizeModePresetIds(
        aiService: AIService,
        promptMapping: [UUID: String],
        userPrompts: [UserPrompt]
    ) {
        var updated = false

        for (index, mode) in aiService.modes.enumerated() {
            guard let presetId = mode.presetId else { continue }

            // Check if the presetId is already a valid preset ID
            if PresetCatalog.builtInIds.contains(presetId) || presetId.hasPrefix("custom_") {
                continue
            }

            // Try to match by title (backward-compat decoder stores title as presetId)
            let normalizedTitle = presetId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if let builtInId = titleToPresetId[normalizedTitle] {
                aiService.modes[index] = VivaMode(
                    id: mode.id,
                    name: mode.name,
                    transcriptionProvider: mode.transcriptionProvider,
                    transcriptionModel: mode.transcriptionModel,
                    transcriptionLanguage: mode.transcriptionLanguage,
                    presetId: builtInId,
                    aiProvider: mode.aiProvider,
                    aiModel: mode.aiModel,
                    aiEnhanceEnabled: mode.aiEnhanceEnabled
                )
                updated = true
                logger.logInfo("Normalized mode '\(mode.name)' presetId: '\(presetId)' → '\(builtInId)'")
            } else {
                // Try matching by title against UserPrompts
                if let matchedPrompt = userPrompts.first(where: { $0.title == presetId }),
                   let mappedId = promptMapping[matchedPrompt.id] {
                    aiService.modes[index] = VivaMode(
                        id: mode.id,
                        name: mode.name,
                        transcriptionProvider: mode.transcriptionProvider,
                        transcriptionModel: mode.transcriptionModel,
                        transcriptionLanguage: mode.transcriptionLanguage,
                        presetId: mappedId,
                        aiProvider: mode.aiProvider,
                        aiModel: mode.aiModel,
                        aiEnhanceEnabled: mode.aiEnhanceEnabled
                    )
                    updated = true
                    logger.logInfo("Normalized mode '\(mode.name)' presetId: '\(presetId)' → '\(mappedId)'")
                }
            }
        }

        if updated {
            aiService.saveModes()
        }
    }
}
