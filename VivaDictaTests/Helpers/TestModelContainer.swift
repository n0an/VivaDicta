// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import SwiftData
@testable import VivaDicta

/// Shared in-memory SwiftData container for integration / acceptance tests.
///
/// Mirrors the production schema declared in `VivaDictaApp.swift` so a model
/// change is caught in ONE place instead of drifting across hand-rolled
/// `ModelContainer(for:)` calls scattered through the suite. `isStoredInMemoryOnly`
/// means no disk and no CloudKit - fast, isolated, and reset per test.
///
/// Keep the type list in sync with `VivaDictaApp.swift`'s `ModelContainer`.
enum TestModelContainer {

    /// A fresh in-memory container holding the full production schema.
    static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Transcription.self, VocabularyWord.self, WordReplacement.self,
            TranscriptionVariation.self, ExtractedReminderDraft.self,
            ExtractedCalendarEventDraft.self,
            CustomRewritePreset.self, RewritePreset.self, TranscriptionTag.self,
            TranscriptionTagAssignment.self, ChatMessage.self, ChatConversation.self,
            MultiNoteConversation.self, SmartSearchConversation.self,
            configurations: config
        )
    }
}
