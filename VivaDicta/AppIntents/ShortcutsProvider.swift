//
//  ShortcutsProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.16
//

import AppIntents

final class ShortcutsProvider: AppShortcutsProvider {
    static let shortcutTileColor = ShortcutTileColor.tangerine
    
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordIntent(),
            phrases: [
                "Record in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Record Note"),
            systemImageName: "microphone.circle.fill"
        )
    }
}
