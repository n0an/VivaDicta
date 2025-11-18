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
                "Start recording in \(.applicationName)",
                "Start a recording in \(.applicationName)",
                "Open \(.applicationName)",
                "\(.applicationName) recording",
                "Take a note in \(.applicationName)",
                "Create a memo in \(.applicationName)",
                "Dictate in \(.applicationName)",
                "New recording in \(.applicationName)",
                "Voice note in \(.applicationName)",
                "Quick note in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Record Note"),
            systemImageName: "microphone.circle.fill"
        )
        AppShortcut(
            intent: ToggleKeyboardFlowIntent(),
            phrases: [
                "Start flow in \(.applicationName)",
                "Toggle flow in \(.applicationName)",
                "Flow in \(.applicationName)",
                "Keyboard session in \(.applicationName)",
                "Start a keyboard session in \(.applicationName)",
                "\(.applicationName) flow"
            ],
            shortTitle: LocalizedStringResource("Start Keyboard Flow"),
            systemImageName: "keyboard.fill"
        )
    }
}
