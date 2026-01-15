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
                "New transcription in \(.applicationName)",
                "Voice note in \(.applicationName)",
                "Quick note in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Record Note"),
            systemImageName: "microphone.circle.fill"
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

        
        
        // Commenting this for now, it's not working how I expected
//        AppShortcut(
//            intent: ToggleKeyboardFlowIntent(),
//            phrases: [
//                "Start flow in \(.applicationName)",
//                "Toggle flow in \(.applicationName)",
//                "Flow in \(.applicationName)",
//                "Keyboard flow in \(.applicationName)",
//                "Start keyboard flow in \(.applicationName)",
//                "Toggle keyboard flow in \(.applicationName)",
//                "\(.applicationName) keyboard flow"
//            ],
//            shortTitle: LocalizedStringResource("Start Keyboard Flow"),
//            systemImageName: "keyboard.fill"
//        )
    }
}
