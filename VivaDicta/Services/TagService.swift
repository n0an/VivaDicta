//
//  TagService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import Foundation
import SwiftData
import os

/// Service for managing user-created tags and their assignments to transcriptions.
@Observable
@MainActor
final class TagService {
    private let logger = Logger(category: .tagService)

    // MARK: - Tag CRUD

    func createTag(name: String, colorHex: String = "#007AFF", icon: String = "tag", in context: ModelContext) -> TranscriptionTag {
        let tag = TranscriptionTag(name: name, colorHex: colorHex, icon: icon)
        context.insert(tag)
        try? context.save()
        logger.logInfo("🏷️ Created tag: \(name)")
        return tag
    }

    func deleteTag(_ tag: TranscriptionTag, in context: ModelContext) {
        // First remove all assignments for this tag
        let tagId = tag.id
        let descriptor = FetchDescriptor<TranscriptionTagAssignment>(
            predicate: #Predicate { $0.tagId == tagId }
        )
        if let assignments = try? context.fetch(descriptor) {
            for assignment in assignments {
                context.delete(assignment)
            }
        }
        context.delete(tag)
        try? context.save()
        logger.logInfo("🏷️ Deleted tag: \(tag.name)")
    }

    func updateTag(_ tag: TranscriptionTag, name: String? = nil, colorHex: String? = nil, icon: String? = nil, in context: ModelContext) {
        if let name { tag.name = name }
        if let colorHex { tag.colorHex = colorHex }
        if let icon { tag.icon = icon }
        try? context.save()
    }

    // MARK: - Tag Assignment

    func assignTag(_ tag: TranscriptionTag, to transcription: Transcription, in context: ModelContext) {
        // Check if already assigned
        let tagId = tag.id
        let existingAssignments = transcription.tagAssignments ?? []
        guard !existingAssignments.contains(where: { $0.tagId == tagId }) else { return }

        let assignment = TranscriptionTagAssignment(tagId: tagId, transcription: transcription)
        context.insert(assignment)
        try? context.save()
        logger.logInfo("🏷️ Assigned tag '\(tag.name)' to transcription")
    }

    func removeTag(_ tag: TranscriptionTag, from transcription: Transcription, in context: ModelContext) {
        let tagId = tag.id
        guard let assignments = transcription.tagAssignments else { return }
        for assignment in assignments where assignment.tagId == tagId {
            context.delete(assignment)
        }
        try? context.save()
        logger.logInfo("🏷️ Removed tag '\(tag.name)' from transcription")
    }

    // MARK: - Queries

    func tags(for transcription: Transcription, allTags: [TranscriptionTag]) -> [TranscriptionTag] {
        let assignedTagIds = Set((transcription.tagAssignments ?? []).map(\.tagId))
        return allTags.filter { assignedTagIds.contains($0.id) }
    }

    func transcriptions(with tag: TranscriptionTag, from transcriptions: [Transcription]) -> [Transcription] {
        let tagId = tag.id
        return transcriptions.filter { transcription in
            (transcription.tagAssignments ?? []).contains { $0.tagId == tagId }
        }
    }
}
