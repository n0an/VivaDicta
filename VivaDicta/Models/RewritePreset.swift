//
//  RewritePreset.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.21
//

import Foundation
import SwiftData

/// A SwiftData model for CloudKit sync of AI presets between iOS and macOS.
///
/// The schema matches the macOS `RewritePreset` model exactly. CloudKit automatically
/// syncs these records via the shared `iCloud.com.antonnovoselov.VivaDicta` container.
///
/// Only custom presets (`isPredefined == false`) are synced. Built-in presets are
/// seeded locally on each platform.
@Model
final class RewritePreset {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "sparkles"
    var category: String = "Custom"
    var systemPrompt: String = ""
    var isPredefined: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isHidden: Bool = false
    var useSystemTemplate: Bool = true

    init(
        id: UUID = UUID(),
        name: String = "",
        icon: String = "sparkles",
        category: String = "Custom",
        systemPrompt: String = "",
        isPredefined: Bool = false,
        sortOrder: Int = 0,
        isHidden: Bool = false,
        useSystemTemplate: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.systemPrompt = systemPrompt
        self.isPredefined = isPredefined
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.isHidden = isHidden
        self.useSystemTemplate = useSystemTemplate
    }
}
