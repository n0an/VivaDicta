//
//  TranscriptionTag.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import Foundation
import SwiftData

/// A user-created tag for organizing transcriptions.
///
/// Tags allow users to categorize transcriptions (e.g., "Meeting", "Personal", "Work").
/// Multiple tags can be assigned to a single transcription via ``TranscriptionTagAssignment``.
@Model
final class TranscriptionTag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"
    var icon: String = "tag"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// When `true`, notes carrying this tag are never removed by the automatic
    /// note or audio cleanup sweeps, regardless of how old they are.
    var isExcludedFromAutoDelete: Bool = false

    init(name: String,
         colorHex: String = "#007AFF",
         icon: String = "tag",
         sortOrder: Int = 0,
         isExcludedFromAutoDelete: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
        self.isExcludedFromAutoDelete = isExcludedFromAutoDelete
    }
}
