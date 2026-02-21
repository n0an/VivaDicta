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

    static let regular = Preset(
        id: "regular",
        name: "Regular",
        icon: "checkmark.seal.fill",
        category: "Rewrite",
        promptInstructions: """
        - Clean up the <TRANSCRIPT> text for clarity and natural flow while preserving meaning and the original tone.
        - Use informal, plain language unless the <TRANSCRIPT> clearly uses a professional tone; in that case, match it.
        - Fix obvious grammar, remove fillers and stutters, collapse repetitions, and keep names and numbers.
        - Handle backtracking and self-corrections: When the speaker corrects themselves mid-sentence using phrases like "scratch that", "actually", "sorry not that", "I mean", "wait no", or similar corrections, remove the incorrect part and keep only the corrected version. Example: "The meeting is on Tuesday, sorry not that, actually Wednesday" → "The meeting is on Wednesday."
        - Respect formatting commands: When the speaker explicitly says "new line" or "new paragraph", insert the appropriate line break or paragraph break at that point.
        - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items"), uses ordinal words (first, second, third), implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
        - Apply smart formatting: Write numbers as numerals (e.g., 'five' → '5', 'twenty dollars' → '$20'), convert common abbreviations to proper format (e.g., 'vs' → 'vs.', 'etc' → 'etc.'), and format dates, times, and measurements consistently.
        - Keep the original intent and nuance.
        - Organize into short paragraphs of 2–4 sentences for readability.
        - Do not add explanations, labels, metadata, or instructions.
        - Output only the cleaned text.
        - Don't add any information not available in the <TRANSCRIPT> text ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let professional = Preset(
        id: "professional",
        name: "Professional",
        icon: "briefcase.fill",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the <TRANSCRIPT> text in a professional, formal tone. \
        Maintain all facts and meaning. Improve structure and clarity. \
        Use business-appropriate language. Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let casual = Preset(
        id: "casual",
        name: "Casual",
        icon: "face.smiling.fill",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the <TRANSCRIPT> text in a casual, friendly tone. \
        Keep it natural and conversational. Maintain all meaning. \
        Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let email = Preset(
        id: "email",
        name: "Email",
        icon: "envelope.fill",
        category: "Rewrite",
        promptInstructions: """
        - Rewrite the <TRANSCRIPT> text as a complete email with proper formatting: include a greeting (Hi), body paragraphs (2-4 sentences each), and closing (Thanks).
        - Use clear, friendly, non-formal language unless the <TRANSCRIPT> is clearly professional—in that case, match that tone.
        - Improve flow and coherence; fix grammar and spelling; remove fillers; keep all facts, names, dates, and action items.
        - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items"), uses ordinal words (first, second, third), implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
        - Write numbers as numerals (e.g., 'five' → '5', 'twenty dollars' → '$20').
        - Do not invent new content, but structure it as a proper email format.
        - Don't add any information not available in the <TRANSCRIPT> text ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let chat = Preset(
        id: "chat",
        name: "Chat",
        icon: "bubble.left.fill",
        category: "Rewrite",
        promptInstructions: """
        - Rewrite the <TRANSCRIPT> text as a chat message: informal, concise, and conversational.
        - Keep emotive markers and emojis if present; don't invent new ones.
        - Lightly fix grammar, remove fillers and repeated words, and improve flow without changing meaning.
        - Keep the original tone; only be professional if the <TRANSCRIPT> already is.
        - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items"), uses ordinal words (first, second, third), implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
        - Write numbers as numerals (e.g., 'five' → '5', 'twenty dollars' → '$20').
        - Format like a modern chat message - short lines, natural breaks, emoji-friendly.
        - Do not add greetings, sign-offs, or commentary.
        - Output only the chat message.
        - Don't add any information not available in the <TRANSCRIPT> text ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let coding = Preset(
        id: "coding",
        name: "Coding",
        icon: "curlybraces",
        category: "Rewrite",
        promptInstructions: """
        Rewrite the <TRANSCRIPT> text as clean, well-structured technical documentation or code-related notes. \
        Preserve all technical terms, variable names, function names, and code references exactly. \
        Format code snippets with proper indentation. Use clear, concise technical language. \
        Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let rewrite = Preset(
        id: "rewrite",
        name: "Rewrite",
        icon: "pencil.circle.fill",
        category: "Rewrite",
        promptInstructions: """
        - Rewrite the <TRANSCRIPT> text with enhanced clarity, improved sentence structure, and rhythmic flow while preserving the original meaning and tone.
        - Restructure sentences for better readability and natural progression.
        - Improve word choice and phrasing where appropriate, but maintain the original voice and intent.
        - Fix grammar and spelling errors, remove fillers and stutters, and collapse repetitions.
        - Format any lists as proper bullet points or numbered lists.
        - Write numbers as numerals (e.g., 'five' → '5', 'twenty dollars' → '$20').
        - Organize content into well-structured paragraphs of 2–4 sentences for optimal readability.
        - Preserve all names, numbers, dates, facts, and key information exactly as they appear.
        - Do not add explanations, labels, metadata, or instructions.
        - Output only the rewritten text.
        - Don't add any information not available in the <TRANSCRIPT> text ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Summarize Presets

    static let summary = Preset(
        id: "summary",
        name: "Summary",
        icon: "doc.text.magnifyingglass",
        category: "Summarize",
        promptInstructions: """
        Summarize the <TRANSCRIPT> text in 2-5 concise bullet points. \
        Focus on the key points, decisions, and important information. \
        Use clear, direct language. Output only the bullet points, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let actionPoints = Preset(
        id: "action_points",
        name: "Action Points",
        icon: "checklist",
        category: "Summarize",
        promptInstructions: """
        Extract all action items, tasks, and to-dos from the <TRANSCRIPT> text. \
        Format as a numbered checklist. Include who is responsible if mentioned. \
        Output only the action items list, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Translate Presets

    static let translateEnglish = Preset(
        id: "translate_en",
        name: "English",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into English. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateRussian = Preset(
        id: "translate_ru",
        name: "Russian",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Russian. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateSpanish = Preset(
        id: "translate_es",
        name: "Spanish",
        icon: "globe",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Spanish. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
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
    ///
    /// Checks built-in presets first, then looks up custom presets from UserDefaults.
    static func displayName(for presetId: String, fallback: String) -> String {
        if let builtIn = allBuiltIn.first(where: { $0.id == presetId }) {
            return builtIn.name
        }
        // Look up custom preset name from shared UserDefaults
        if let data = UserDefaultsStorage.shared.data(forKey: "Presets_v1"),
           let presets = try? JSONDecoder().decode([Preset].self, from: data),
           let preset = presets.first(where: { $0.id == presetId }) {
            return preset.name
        }
        return fallback
    }

    /// Returns the icon for a preset ID.
    static func icon(for presetId: String) -> String {
        allBuiltIn.first { $0.id == presetId }?.icon ?? "sparkles"
    }

    // MARK: - CloudKit UUID Mapping

    /// Stable UUIDs matching macOS RewritePreset records for CloudKit sync.
    /// These must stay in sync with macOS `RewritePreset.builtInDefinitions` UUIDs.
    static let builtInUUIDs: [String: UUID] = [
        "regular":       UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        "summary":       UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        "action_points": UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        "professional":  UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        "casual":        UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
        "email":         UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
        "chat":          UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
        "coding":        UUID(uuidString: "00000000-0000-0000-0000-000000000024")!,
        "rewrite":       UUID(uuidString: "00000000-0000-0000-0000-000000000025")!,
        "translate_en":  UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        "translate_ru":  UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
        "translate_es":  UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
    ]

    /// Reverse lookup: UUID → built-in preset ID string.
    private static let uuidToBuiltInId: [UUID: String] = {
        Dictionary(uniqueKeysWithValues: builtInUUIDs.map { ($1, $0) })
    }()

    /// Returns the stable CloudKit UUID for a built-in preset ID.
    static func uuid(for presetId: String) -> UUID? {
        builtInUUIDs[presetId]
    }

    /// Returns the built-in preset ID for a CloudKit UUID.
    static func presetId(for uuid: UUID) -> String? {
        uuidToBuiltInId[uuid]
    }
}
