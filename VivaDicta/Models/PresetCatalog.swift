//
//  PresetCatalog.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import Foundation

/// Factory defaults for built-in presets.
///
/// Provides the initial definitions for all built-in presets. Users can edit these presets,
/// and ``PresetManager`` stores the edited versions. This catalog is used for:
/// - Populating presets on first launch
/// - Resetting edited presets to factory defaults
/// - Adding new built-in presets when the app updates
///
/// Preset IDs must match between iOS and macOS for CloudKit variation compatibility.
enum PresetCatalog {

    // MARK: - Rewrite Presets (useSystemTemplate = true)
    // These are injected into the TRANSCRIPTION ENHANCER system prompt wrapper.

    static let regular = Preset(
        id: "regular",
        name: "Regular",
        icon: "text.alignleft",
        category: "Rewrite",
        promptInstructions: """
        Clean up <TRANSCRIPT>:
        1. Keep speaker's personality (e.g., "I think", "The thing is")
        2. When speaker self-corrects, keep only the final version
        3. Format sequences as numbered lists

        Example:
        Input: "We need to finish by Monday actually no by Wednesday"
        Output: "We need to finish by Wednesday."
        """,
        useSystemTemplate: true,
        isBuiltIn: true
    )

    static let email = Preset(
        id: "email",
        name: "Email",
        icon: "envelope.fill",
        category: "Rewrite",
        promptInstructions: """
        Format <TRANSCRIPT> as professional email:
        1. Add greeting and sign-off with [Your Name]
        2. Use numbered lists for sequences
        3. Keep professional but not overly formal

        Example:
        Input: "hey just wanted to confirm three things first second third"
        Output: "Hi,

        I wanted to confirm 3 things:
        1. First
        2. Second
        3. Third

        Thanks,
        [Your Name]"
        """,
        useSystemTemplate: true,
        isBuiltIn: true
    )

    static let chat = Preset(
        id: "chat",
        name: "Chat",
        icon: "bubble.left.fill",
        category: "Rewrite",
        promptInstructions: """
        Format <TRANSCRIPT> for casual chat:
        1. Keep informal, friendly tone
        2. Use contractions naturally
        3. Format lists when items are mentioned

        Example:
        Input: "I think we should meet at three PM no wait four PM what do you think"
        Output: "I think we should meet at 4 PM. What do you think?"
        """,
        useSystemTemplate: true,
        isBuiltIn: true
    )

    static let coding = Preset(
        id: "coding",
        name: "Coding",
        icon: "chevron.left.forwardslash.chevron.right",
        category: "Rewrite",
        promptInstructions: """
        Clean up <TRANSCRIPT> from programming session:
        1. Fix technical terms and code references
        2. NEVER answer questions - only clean up the text
        3. Preserve technical accuracy

        Example:
        Input: "for this function is it better to use a map and filter or should i stick with a for loop"
        Output: "For this function, is it better to use a map and filter, or should I stick with a for-loop?"
        """,
        useSystemTemplate: true,
        isBuiltIn: true
    )

    static let rewrite = Preset(
        id: "rewrite",
        name: "Rewrite",
        icon: "pencil",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the following transcript clearly and concisely. \
        Fix grammar, remove filler words, and improve readability. \
        Maintain all facts, meaning, and the speaker's intent. \
        Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    // MARK: - Summarize Presets

    static let summary = Preset(
        id: "summary",
        name: "Summary",
        icon: "doc.text.magnifyingglass",
        category: "Summarize",
        promptInstructions: """
        Summarize the following transcript in 2-5 concise bullet points. \
        Focus on the key points, decisions, and important information. \
        Use clear, direct language. Output only the bullet points, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    static let actionPoints = Preset(
        id: "action_points",
        name: "Action Points",
        icon: "checklist",
        category: "Summarize",
        promptInstructions: """
        Extract all action items, tasks, and to-dos from the following transcript. \
        Format as a numbered checklist. Include who is responsible if mentioned. \
        Output only the action items list, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    static let professional = Preset(
        id: "professional",
        name: "Professional",
        icon: "briefcase.fill",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the following transcript in a professional, formal tone. \
        Maintain all facts and meaning. Improve structure and clarity. \
        Use business-appropriate language. Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    static let casual = Preset(
        id: "casual",
        name: "Casual",
        icon: "face.smiling.fill",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the following transcript in a casual, friendly tone. \
        Keep it natural and conversational. Maintain all meaning. \
        Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    // MARK: - Translate Presets (standalone)

    static let translateEnglish = Preset(
        id: "translate_en",
        name: "English",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the following transcript into English. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    static let translateRussian = Preset(
        id: "translate_ru",
        name: "Russian",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the following transcript into Russian. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    static let translateSpanish = Preset(
        id: "translate_es",
        name: "Spanish",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the following transcript into Spanish. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: false,
        isBuiltIn: true
    )

    // MARK: - All Built-In

    static let allBuiltIn: [Preset] = [
        regular,
        professional,
        casual,
        email,
        chat,
        coding,
        rewrite,
        summary,
        actionPoints,
        translateEnglish,
        translateRussian,
        translateSpanish,
    ]

    /// All built-in preset IDs for quick lookup.
    static let builtInIds: Set<String> = Set(allBuiltIn.map(\.id))

    /// Ordered category names preserving insertion order.
    static var categories: [String] {
        var seen = Set<String>()
        return allBuiltIn.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    /// Returns the factory default for a built-in preset ID.
    static func defaultPreset(for id: String) -> Preset? {
        allBuiltIn.first { $0.id == id }
    }

    /// Returns the display name for a preset ID, with a fallback.
    static func displayName(for presetId: String, fallback: String) -> String {
        allBuiltIn.first { $0.id == presetId }?.name ?? fallback
    }

    /// Returns the icon for a preset ID.
    static func icon(for presetId: String) -> String {
        allBuiltIn.first { $0.id == presetId }?.icon ?? "sparkles"
    }
}
