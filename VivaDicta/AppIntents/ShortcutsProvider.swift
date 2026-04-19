//
//  ShortcutsProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.16
//

import AppIntents

final class ShortcutsProvider: AppShortcutsProvider {
    static let shortcutTileColor = ShortcutTileColor.lime
    
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordIntent(),
            phrases: [
                "Record in \(.applicationName)",
                "Record note in \(.applicationName)",
                "Note in \(.applicationName)",
                "Transcribe in \(.applicationName)",
                "Start recording in \(.applicationName)",
                "Start a recording in \(.applicationName)",
                "Open \(.applicationName)",
                "\(.applicationName) recording",
                "\(.applicationName) transcribing",
                "Take a note in \(.applicationName)",
                "Create a memo in \(.applicationName)",
                "Dictate in \(.applicationName)",
                "New recording in \(.applicationName)",
                "New note in \(.applicationName)",
                "Voice note in \(.applicationName)",
                "Quick note in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Record Note"),
            systemImageName: "microphone.circle.fill"
        )

        AppShortcut(
            intent: OpenSearchIntent(),
            phrases: [
                "Search in \(.applicationName)",
                "Search notes in \(.applicationName)",
                "Open \(.applicationName) search",
                "Search my \(.applicationName) notes"
            ],
            shortTitle: LocalizedStringResource("Search"),
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: OpenAskAIIntent(),
            phrases: [
                "Ask AI in \(.applicationName)",
                "Ask the AI in \(.applicationName)",
                "Open \(.applicationName) chats",
                "Ask \(.applicationName) AI",
                "Ask AI about my \(.applicationName) notes"
            ],
            shortTitle: LocalizedStringResource("Ask AI"),
            systemImageName: "bubble.left.and.bubble.right.fill"
        )

        AppShortcut(
            intent: GetLatestTranscriptionIntent(),
            phrases: [
                "Get latest note from \(.applicationName)",
                "Latest note in \(.applicationName)",
                "My most recent note in \(.applicationName)"
            ],
            shortTitle: "Get Latest Note",
            systemImageName: "text.quote"
        )

        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Find notes in \(.applicationName)",
                "Find a note in \(.applicationName)",
                "Look up a note in \(.applicationName)"
            ],
            shortTitle: "Find Notes",
            systemImageName: "text.magnifyingglass"
        )
        
        AppShortcut(
            intent: CountRecentTranscriptionsIntent(),
            phrases: [
                "Count my recent notes in \(.applicationName)"
            ],
            shortTitle: "Recent Notes Count",
            systemImageName: "document.on.document"
        )
        
        AppShortcut(
            intent: TranscriptionReminderIntent(),
            phrases: [
                "Remind me of a \(.applicationName) note"
            ],
            shortTitle: "Remind me of a Note",
            systemImageName: "text.page.badge.magnifyingglass"
        )
        
        AppShortcut(
            intent: AddToRecentTranscriptionIntent(),
            phrases: [
                "Add to my most recent note in \(.applicationName)"
            ],
            shortTitle: "Add to Recent Note",
            systemImageName: "document.badge.plus"
        )
        
        AppShortcut(
            intent: OpenTranscriptionSnippetIntent(),
            phrases: [
                "Open a note in \(.applicationName)"
            ],
            shortTitle: "Open a note",
            systemImageName: "document.viewfinder"
        )
    }
}
