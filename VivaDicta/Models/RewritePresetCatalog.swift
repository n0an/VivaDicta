//
//  RewritePresetCatalog.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation

struct RewritePreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let category: String
    let systemPrompt: String
}

enum RewritePresetCatalog {

    // MARK: - Summarize

    static let summary = RewritePreset(
        id: "summary",
        name: "Summary",
        icon: "doc.text.magnifyingglass",
        category: "Summarize",
        systemPrompt: """
        Summarize the following transcript in 2-5 concise bullet points. \
        Focus on the key points, decisions, and important information. \
        Use clear, direct language. Output only the bullet points, nothing else.
        """
    )

    static let actionPoints = RewritePreset(
        id: "action_points",
        name: "Action Points",
        icon: "checklist",
        category: "Summarize",
        systemPrompt: """
        Extract all action items, tasks, and to-dos from the following transcript. \
        Format as a numbered checklist. Include who is responsible if mentioned. \
        Output only the action items list, nothing else.
        """
    )

    // MARK: - Rewrite

    static let professional = RewritePreset(
        id: "professional",
        name: "Professional",
        icon: "briefcase.fill",
        category: "Rewrite",
        systemPrompt: """
        Rewrite the following transcript in a professional, formal tone. \
        Maintain all facts and meaning. Improve structure and clarity. \
        Use business-appropriate language. Output only the rewritten text, nothing else.
        """
    )

    static let casual = RewritePreset(
        id: "casual",
        name: "Casual",
        icon: "face.smiling.fill",
        category: "Rewrite",
        systemPrompt: """
        Rewrite the following transcript in a casual, friendly tone. \
        Keep it natural and conversational. Maintain all meaning. \
        Output only the rewritten text, nothing else.
        """
    )

    // MARK: - Translate

    static let translateEnglish = RewritePreset(
        id: "translate_en",
        name: "English",
        icon: "globe",
        category: "Translate",
        systemPrompt: """
        Translate the following transcript into English. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """
    )

    static let translateRussian = RewritePreset(
        id: "translate_ru",
        name: "Russian",
        icon: "globe",
        category: "Translate",
        systemPrompt: """
        Translate the following transcript into Russian. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """
    )

    // MARK: - All Built-In

    static let allBuiltIn: [RewritePreset] = [
        summary,
        actionPoints,
        professional,
        casual,
        translateEnglish,
        translateRussian,
    ]

    static var categories: [String] {
        var seen = Set<String>()
        return allBuiltIn.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    static func preset(for id: String) -> RewritePreset? {
        allBuiltIn.first { $0.id == id }
    }

    static func displayName(for presetId: String, fallback: String) -> String {
        preset(for: presetId)?.name ?? fallback
    }

    static func icon(for presetId: String) -> String {
        preset(for: presetId)?.icon ?? "sparkles"
    }
}
