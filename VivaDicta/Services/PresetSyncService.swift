//
//  PresetSyncService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.21
//

import Foundation
import SwiftData
import os

/// Bridges RewritePreset SwiftData records (CloudKit-synced) with PresetManager (UserDefaults).
///
/// CloudKit automatically syncs `RewritePreset` records between iOS and macOS via the shared
/// `iCloud.com.antonnovoselov.VivaDicta` container. This service handles:
///
/// - **Custom preset sync**: Reading/writing custom `RewritePreset` records (`isPredefined == false`)
///   bidirectionally between SwiftData and ``PresetManager``.
/// - **Built-in preset sync**: Syncing user edits to built-in presets (`isPredefined == true`)
///   using stable UUIDs shared with macOS (see ``PresetCatalog/builtInUUIDs``).
/// - **Migration**: One-time migration of existing custom presets and old
///   ``CustomRewritePreset`` records to the new `RewritePreset` model.
@Observable
class PresetSyncService {
    private let logger = Logger(category: .presetSync)
    private var modelContext: ModelContext?

    private static let migratedPresetsKey = "HasMigratedPresetsToRewritePreset_v1"
    private static let migratedCustomRewriteKey = "HasMigratedCustomRewriteToRewritePreset_v1"

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Sync from CloudKit → PresetManager

    /// Reads custom RewritePreset records from SwiftData and merges into PresetManager.
    /// Call on app launch and when CloudKit delivers changes.
    func syncFromCloudKit(presetManager: PresetManager) {
        guard let context = modelContext else {
            logger.logWarning("ModelContext not configured, skipping CloudKit sync")
            return
        }

        let customRecords = fetchCustomPresets(context: context)
        logger.logInfo("Found \(customRecords.count) custom RewritePreset records in SwiftData")

        for record in customRecords {
            let presetId = "custom_\(record.id.uuidString)"

            // Skip hidden presets — remove from PresetManager if present
            guard !record.isHidden else {
                if presetManager.preset(for: presetId) != nil {
                    let placeholder = Preset(
                        id: presetId, name: "", icon: "", category: "",
                        promptInstructions: "", useSystemTemplate: false, isBuiltIn: false
                    )
                    presetManager.deletePreset(placeholder)
                    logger.logInfo("Removed hidden preset: \(record.name)")
                }
                continue
            }

            let preset = convertToPreset(record)

            if presetManager.preset(for: preset.id) != nil {
                presetManager.updatePreset(preset)
            } else {
                presetManager.addPreset(preset)
                logger.logInfo("Synced preset from CloudKit: \(preset.name)")
            }
        }

        // Remove local custom presets that were deleted on the other platform
        let cloudPresetIds = Set(customRecords.map { "custom_\($0.id.uuidString)" })
        let localCustomPresets = presetManager.presets.filter {
            $0.id.hasPrefix("custom_") && !$0.isBuiltIn
        }
        for localPreset in localCustomPresets {
            if !cloudPresetIds.contains(localPreset.id) {
                // Only remove if the migration has already run (meaning we've had a chance
                // to write our local presets to SwiftData). Otherwise this is a preset
                // created locally that hasn't been synced yet.
                if UserDefaults.standard.bool(forKey: Self.migratedPresetsKey) {
                    presetManager.deletePreset(localPreset)
                    logger.logInfo("Removed locally deleted preset: \(localPreset.name)")
                }
            }
        }

        // Sync edited built-in presets from CloudKit
        syncBuiltInPresetsFromCloudKit(context: context, presetManager: presetManager)
    }

    // MARK: - Write to CloudKit

    /// Creates a RewritePreset record in SwiftData for CloudKit sync.
    func createPresetRecord(from preset: Preset) {
        guard let context = modelContext else { return }
        guard let uuid = extractUUID(from: preset.id) else { return }

        let record = RewritePreset(
            id: uuid,
            name: preset.name,
            icon: preset.icon,
            category: preset.category,
            systemPrompt: preset.promptInstructions,
            isPredefined: false,
            sortOrder: 1000,
            isHidden: false,
            isFavorite: preset.isFavorite,
            useSystemTemplate: preset.useSystemTemplate,
            wrapInTranscriptTags: preset.wrapInTranscriptTags,
            presetDescription: preset.presetDescription
        )

        context.insert(record)
        saveContext(context)
        logger.logInfo("Created RewritePreset record for sync: \(preset.name)")
    }

    /// Updates an existing RewritePreset record in SwiftData.
    func updatePresetRecord(from preset: Preset) {
        guard let context = modelContext,
              let uuid = extractUUID(from: preset.id) else { return }

        if let existing = fetchPreset(by: uuid, context: context) {
            existing.name = preset.name
            existing.icon = preset.icon
            existing.category = preset.category
            existing.systemPrompt = preset.promptInstructions
            existing.useSystemTemplate = preset.useSystemTemplate
            existing.wrapInTranscriptTags = preset.wrapInTranscriptTags
            existing.presetDescription = preset.presetDescription
            existing.isFavorite = preset.isFavorite
            saveContext(context)
            logger.logInfo("Updated RewritePreset record: \(preset.name)")
        } else {
            createPresetRecord(from: preset)
        }
    }

    /// Deletes a RewritePreset record from SwiftData.
    func deletePresetRecord(presetId: String) {
        guard let context = modelContext,
              let uuid = extractUUID(from: presetId) else { return }

        if let existing = fetchPreset(by: uuid, context: context) {
            context.delete(existing)
            saveContext(context)
            logger.logInfo("Deleted RewritePreset record: \(existing.name)")
        }
    }

    // MARK: - Built-In Preset Sync

    /// Writes an edited built-in preset to SwiftData for CloudKit sync.
    func syncBuiltInPresetRecord(from preset: Preset) {
        // Assistant prompt differs by design between platforms — don't sync
        guard preset.id != "assistant" else { return }
        guard let context = modelContext,
              let uuid = PresetCatalog.uuid(for: preset.id) else { return }

        if let existing = fetchPreset(by: uuid, context: context) {
            existing.systemPrompt = preset.promptInstructions
            existing.useSystemTemplate = preset.useSystemTemplate
            existing.wrapInTranscriptTags = preset.wrapInTranscriptTags
            existing.isFavorite = preset.isFavorite
        } else {
            let record = RewritePreset(
                id: uuid,
                name: preset.name,
                icon: preset.icon,
                category: preset.category,
                systemPrompt: preset.promptInstructions,
                isPredefined: true,
                sortOrder: 0,
                isFavorite: preset.isFavorite,
                useSystemTemplate: preset.useSystemTemplate,
                wrapInTranscriptTags: preset.wrapInTranscriptTags
            )
            context.insert(record)
        }

        saveContext(context)
        logger.logInfo("Synced built-in preset to CloudKit: \(preset.name)")
    }

    /// Resets a built-in preset record in SwiftData to catalog defaults, propagating via CloudKit.
    func resetBuiltInPresetRecord(presetId: String) {
        guard let context = modelContext,
              let uuid = PresetCatalog.uuid(for: presetId),
              let catalogDefault = PresetCatalog.defaultPreset(for: presetId),
              let existing = fetchPreset(by: uuid, context: context) else { return }

        existing.systemPrompt = catalogDefault.promptInstructions
        existing.useSystemTemplate = catalogDefault.useSystemTemplate
        existing.wrapInTranscriptTags = catalogDefault.wrapInTranscriptTags
        saveContext(context)
        logger.logInfo("Reset built-in preset record to default: \(catalogDefault.name)")
    }

    /// Syncs the favorite state of a preset to SwiftData/CloudKit.
    /// Works for both custom presets (by extracted UUID) and built-in presets (by catalog UUID).
    func syncFavoriteState(presetId: String, isFavorite: Bool) {
        guard let context = modelContext else { return }

        let uuid: UUID?
        if presetId.hasPrefix("custom_") {
            uuid = extractUUID(from: presetId)
        } else {
            uuid = PresetCatalog.uuid(for: presetId)
        }

        guard let uuid else { return }

        if let existing = fetchPreset(by: uuid, context: context) {
            existing.isFavorite = isFavorite
            saveContext(context)
            logger.logInfo("Synced favorite state to CloudKit: \(presetId) → \(isFavorite)")
        } else if !presetId.hasPrefix("custom_") {
            // Built-in preset doesn't have a record yet — create one for favorite sync
            guard let catalogDefault = PresetCatalog.defaultPreset(for: presetId) else { return }
            let record = RewritePreset(
                id: uuid,
                name: catalogDefault.name,
                icon: catalogDefault.icon,
                category: catalogDefault.category,
                systemPrompt: catalogDefault.promptInstructions,
                isPredefined: true,
                sortOrder: 0,
                isFavorite: isFavorite,
                useSystemTemplate: catalogDefault.useSystemTemplate,
                wrapInTranscriptTags: catalogDefault.wrapInTranscriptTags
            )
            context.insert(record)
            saveContext(context)
            logger.logInfo("Created built-in RewritePreset record for favorite sync: \(presetId)")
        }
    }

    // MARK: - Migration

    /// Migrates existing custom presets from PresetManager (UserDefaults) to RewritePreset (SwiftData).
    /// One-time operation on first launch after this update.
    func migrateExistingCustomPresets(presetManager: PresetManager) {
        guard !UserDefaults.standard.bool(forKey: Self.migratedPresetsKey) else { return }

        let customPresets = presetManager.presets.filter { $0.id.hasPrefix("custom_") }
        for preset in customPresets {
            createPresetRecord(from: preset)
        }

        UserDefaults.standard.set(true, forKey: Self.migratedPresetsKey)
        logger.logInfo("Migrated \(customPresets.count) existing custom presets to RewritePreset")
    }

    /// Migrates old CustomRewritePreset records to the new RewritePreset model.
    /// One-time operation — the old records are deleted after migration.
    func migrateOldCustomRewritePresets() {
        guard let context = modelContext else { return }
        guard !UserDefaults.standard.bool(forKey: Self.migratedCustomRewriteKey) else { return }

        let oldRecords = (try? context.fetch(FetchDescriptor<CustomRewritePreset>())) ?? []
        for old in oldRecords {
            let newRecord = RewritePreset(
                id: old.id,
                name: old.name,
                icon: old.icon,
                category: old.category,
                systemPrompt: old.systemPrompt,
                isPredefined: false,
                sortOrder: old.sortOrder + 1000
            )
            context.insert(newRecord)
            context.delete(old)
        }

        if !oldRecords.isEmpty {
            saveContext(context)
            logger.logInfo("Migrated \(oldRecords.count) old CustomRewritePreset records to RewritePreset")
        }

        UserDefaults.standard.set(true, forKey: Self.migratedCustomRewriteKey)
    }

    // MARK: - Built-In Inbound Sync

    /// Reads predefined RewritePreset records from SwiftData and applies edits to local built-in presets.
    /// Detects edits by comparing against PresetCatalog defaults.
    private func syncBuiltInPresetsFromCloudKit(context: ModelContext, presetManager: PresetManager) {
        let predefinedRecords = fetchPredefinedPresets(context: context)
        guard !predefinedRecords.isEmpty else { return }

        logger.logInfo("Found \(predefinedRecords.count) predefined RewritePreset records in SwiftData")

        for record in predefinedRecords {
            guard let builtInId = PresetCatalog.presetId(for: record.id),
                  let catalogDefault = PresetCatalog.defaultPreset(for: builtInId),
                  let localPreset = presetManager.preset(for: builtInId) else { continue }

            // Assistant prompt differs by design between platforms — skip inbound sync
            if builtInId == "assistant" { continue }

            let isEdited = record.systemPrompt != catalogDefault.promptInstructions
                || record.useSystemTemplate != catalogDefault.useSystemTemplate
                || record.wrapInTranscriptTags != catalogDefault.wrapInTranscriptTags

            if isEdited {
                // Another device edited this built-in preset — apply the edits locally
                var updated = localPreset
                updated.promptInstructions = record.systemPrompt
                updated.useSystemTemplate = record.useSystemTemplate
                updated.wrapInTranscriptTags = record.wrapInTranscriptTags
                updated.isFavorite = record.isFavorite
                updated.isEdited = true
                presetManager.updatePreset(updated)
                logger.logInfo("Applied CloudKit edits to built-in preset: \(builtInId)")
            } else if localPreset.isEdited {
                // CloudKit record matches catalog defaults (was reset on another device)
                presetManager.resetToDefault(presetId: builtInId)
                logger.logInfo("Reset built-in preset from CloudKit: \(builtInId)")
            }

            // Sync isFavorite regardless of edit state
            if localPreset.isFavorite != record.isFavorite {
                if let currentPreset = presetManager.preset(for: builtInId), currentPreset.isFavorite != record.isFavorite {
                    var updated = currentPreset
                    updated.isFavorite = record.isFavorite
                    presetManager.updatePreset(updated)
                    logger.logInfo("Synced favorite state from CloudKit for: \(builtInId)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func fetchPredefinedPresets(context: ModelContext) -> [RewritePreset] {
        var descriptor = FetchDescriptor<RewritePreset>(
            predicate: #Predicate { $0.isPredefined }
        )
        descriptor.fetchLimit = 50
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCustomPresets(context: ModelContext) -> [RewritePreset] {
        var descriptor = FetchDescriptor<RewritePreset>(
            predicate: #Predicate { !$0.isPredefined },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        descriptor.fetchLimit = 200
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPreset(by id: UUID, context: ModelContext) -> RewritePreset? {
        var descriptor = FetchDescriptor<RewritePreset>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func extractUUID(from presetId: String) -> UUID? {
        guard presetId.hasPrefix("custom_") else { return nil }
        return UUID(uuidString: String(presetId.dropFirst("custom_".count)))
    }

    /// Converts a RewritePreset SwiftData record to a local Preset struct.
    private func convertToPreset(_ record: RewritePreset) -> Preset {
        // Map legacy macOS categories to iOS equivalents
        let mappedCategory: String
        switch record.category {
        case "General", "Custom":
            mappedCategory = "Other"
        default:
            mappedCategory = record.category
        }

        return Preset(
            id: "custom_\(record.id.uuidString)",
            name: record.name,
            icon: record.icon,
            presetDescription: record.presetDescription,
            category: mappedCategory,
            promptInstructions: record.systemPrompt,
            useSystemTemplate: record.useSystemTemplate,
            wrapInTranscriptTags: record.wrapInTranscriptTags,
            isBuiltIn: false,
            isFavorite: record.isFavorite,
            createdAt: record.createdAt
        )
    }

    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.logError("Failed to save ModelContext: \(error.localizedDescription)")
        }
    }
}
