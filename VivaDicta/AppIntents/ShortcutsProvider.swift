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
