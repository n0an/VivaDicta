//
//  TranscriptionTagAssignment.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import Foundation
import SwiftData

/// Junction model linking a ``TranscriptionTag`` to a ``Transcription``.
///
/// Uses a junction model instead of a direct many-to-many relationship
/// for reliable CloudKit sync compatibility.
@Model
final class TranscriptionTagAssignment {
    var id: UUID = UUID()
    var tagId: UUID = UUID()
    var createdAt: Date = Date()

    @Relationship(inverse: \Transcription.tagAssignments)
    var transcription: Transcription?

    init(tagId: UUID, transcription: Transcription? = nil) {
        self.tagId = tagId
        self.transcription = transcription
    }
}
