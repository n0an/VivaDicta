//
//  CustomRewritePreset.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation
import SwiftData

/// Legacy SwiftData model for user-created custom rewrite presets.
///
/// Superseded by ``RewritePreset`` for CloudKit sync. Kept in the schema for
/// migration purposes — ``PresetSyncService`` migrates these records to
/// `RewritePreset` on first launch.
@Model
final class CustomRewritePreset {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "✨"
    var category: String = "Custom"
    var systemPrompt: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String,
         icon: String = "✨",
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

}
