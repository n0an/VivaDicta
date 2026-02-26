//
//  WhatsNewContent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.26
//

import SwiftUI

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColors: [Color]
    let title: String
    let description: String
}

struct WhatsNewRelease: Identifiable {
    let id: String
    let headline: String
    let features: [WhatsNewFeature]
}

enum WhatsNewCatalog {
    static func release(for version: String) -> WhatsNewRelease? {
        let majorMinor = version.split(separator: ".").prefix(2).joined(separator: ".")
        return releases[majorMinor]
    }

    private static let releases: [String: WhatsNewRelease] = [
        "2.0": release_2_0
    ]

    private static let release_2_0 = WhatsNewRelease(
        id: "2.0",
        headline: "What's New in VivaDicta 2.0",
        features: [
            WhatsNewFeature(
                icon: "macbook.and.iphone",
                iconColors: [.blue, .cyan],
                title: "VivaDicta for Mac",
                description: "Now available on macOS with the same transcription and AI workflow, fully synced via iCloud."
            ),
            WhatsNewFeature(
                icon: "icloud",
                iconColors: [.cyan, .blue],
                title: "iCloud Sync",
                description: "Transcriptions, presets, dictionary, and API keys sync across iPhone, iPad, and Mac."
            ),
            WhatsNewFeature(
                icon: "bubble.left.and.text.bubble.right",
                iconColors: [.purple, .pink],
                title: "AI Assistant",
                description: "A new preset turns VivaDicta into a voice-powered AI assistant. Speak a question — get a formatted answer."
            ),
            WhatsNewFeature(
                icon: "translate",
                iconColors: [.green, .mint],
                title: "Auto-Translation",
                description: "Set a Translate preset as your mode's default — every recording is automatically translated."
            ),
            WhatsNewFeature(
                icon: "square.stack.3d.up",
                iconColors: [.orange, .yellow],
                title: "AI Presets & Variations",
                description: "Process text with different presets — Summary, Email, Coding, and more. Each result saved as a variation."
            ),
            WhatsNewFeature(
                icon: "clipboard",
                iconColors: [.indigo, .purple],
                title: "Clipboard & Text Context",
                description: "AI processing can use your clipboard or selected text as additional context for smarter results."
            ),
            WhatsNewFeature(
                icon: "keyboard",
                iconColors: [.teal, .blue],
                title: "Keyboard Improvements",
                description: "Swipe to switch modes, recording timer, and improved processing status."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.pink, .orange],
                title: "Quality of Life",
                description: "Auto-copy, copy buttons, searchable model picker, multi-select deletion, and a redesigned detail view."
            )
        ]
    )
}
