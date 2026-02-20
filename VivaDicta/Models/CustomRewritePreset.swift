//
//  CustomRewritePreset.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import SwiftData

/// A SwiftData model representing a user-created custom rewrite preset.
///
/// Custom presets are synced via CloudKit between iOS and macOS.
/// Built-in presets live in ``RewritePresetCatalog`` (static code, not SwiftData).
///
/// The schema must match the macOS `CustomRewritePreset` model exactly for CloudKit sync.
@Model
final class CustomRewritePreset {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "sparkles"
    var category: String = "Custom"
    var systemPrompt: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String,
         icon: String = "sparkles",
         category: String = "Custom",
         systemPrompt: String,
         sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.category = category
        self.systemPrompt = systemPrompt
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    /// Converts to the common `RewritePreset` struct used by the AI pipeline.
    func toRewritePreset() -> RewritePreset {
        RewritePreset(
            id: "custom_\(id.uuidString)",
            name: name,
            icon: icon,
            category: category,
            systemPrompt: systemPrompt
        )
    }
}
