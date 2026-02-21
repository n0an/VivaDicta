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
/// - **Inbound sync**: Reading custom `RewritePreset` records from SwiftData and merging
///   them into ``PresetManager`` so they appear in the preset picker.
/// - **Outbound sync**: Writing `RewritePreset` records when the user creates, edits,
///   or deletes custom presets on iOS.
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
            category: mapCategoryToMacOS(preset.category),
            systemPrompt: preset.promptInstructions,
            isPredefined: false,
            sortOrder: 1000,
            isHidden: false,
            useSystemTemplate: preset.useSystemTemplate
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
            existing.category = mapCategoryToMacOS(preset.category)
            existing.systemPrompt = preset.promptInstructions
            existing.useSystemTemplate = preset.useSystemTemplate
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

    // MARK: - Helpers

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
        let mappedCategory: String
        switch record.category {
        case "General", "Assistant", "Custom":
            mappedCategory = "Other"
        default:
            mappedCategory = record.category
        }

        return Preset(
            id: "custom_\(record.id.uuidString)",
            name: record.name,
            icon: record.icon,
            category: mappedCategory,
            promptInstructions: record.systemPrompt,
            useSystemTemplate: record.useSystemTemplate,
            wrapInTranscriptTags: record.useSystemTemplate,
            isBuiltIn: false,
            createdAt: record.createdAt
        )
    }

    private func mapCategoryToMacOS(_ iosCategory: String) -> String {
        switch iosCategory {
        case "Other": return "Custom"
        default: return iosCategory
        }
    }

    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.logError("Failed to save ModelContext: \(error.localizedDescription)")
        }
    }
}
