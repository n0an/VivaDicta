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
        icon: "✨",
        presetDescription: "Clean up for clarity",
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

    static let coding = Preset(
        id: "coding",
        name: "Coding",
        icon: "💻",
        presetDescription: "Technical documentation",
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
        icon: "✍️",
        presetDescription: "Enhanced clarity & flow",
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

    static let simplify = Preset(
        id: "simplify",
        name: "Simplify",
        icon: "🔤",
        presetDescription: "Use simpler words and sentences",
        category: "Rewrite",
        promptInstructions: """
        Simplify the <TRANSCRIPT> using simpler words and shorter sentences. \
        Make it easier to understand while keeping the meaning. \
        Output only the simplified text, nothing else. \
        Don't add any information not available in the <TRANSCRIPT> ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let proofreading = Preset(
        id: "proofreading",
        name: "Proofreading",
        icon: "🔍",
        presetDescription: "Fix spelling & grammar",
        category: "Rewrite",
        promptInstructions: """
        Proofread the <TRANSCRIPT> and fix all punctuation, spelling, and grammar errors. \
        Do not change the meaning, tone, or structure. Output only the corrected text.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Format Presets

    static let structured = Preset(
        id: "structured",
        name: "Structured",
        icon: "📄",
        presetDescription: "Add headings & sections",
        category: "Format",
        promptInstructions: """
        Organize and format the <TRANSCRIPT> into a well-structured document. \
        Add appropriate headings, sections, and formatting. \
        Ensure logical flow and clear hierarchy. Output only the structured text.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let list = Preset(
        id: "list",
        name: "List",
        icon: "📋",
        presetDescription: "Convert to bullet points",
        category: "Format",
        promptInstructions: """
        Convert the <TRANSCRIPT> into a clear, organized bullet point list. \
        Group related items together. Use sub-bullets for details when needed. \
        Output only the bullet point list.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let table = Preset(
        id: "table",
        name: "Table",
        icon: "🗂️",
        presetDescription: "Organize into a table",
        category: "Format",
        promptInstructions: """
        Organize the information from the <TRANSCRIPT> into a plain-text table. \
        Choose appropriate column headers based on the content. \
        Use | to separate columns and - for the header separator line. \
        Pad each cell with spaces so columns are aligned. \
        Do NOT add a title, header, or label before or after the table. \
        Do NOT invent or fabricate information. Only include what is present in the <TRANSCRIPT>. \
        If information for a cell is not available, leave it empty. \
        Output only the table, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Style Presets

    static let professional = Preset(
        id: "professional",
        name: "Professional",
        icon: "💼",
        presetDescription: "Formal business tone",
        category: "Style",
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
        icon: "😊",
        presetDescription: "Relaxed & friendly tone",
        category: "Style",
        promptInstructions: """
        Rewrite the <TRANSCRIPT> text in a casual, friendly tone. \
        Keep it natural and conversational. Maintain all meaning. \
        Output only the rewritten text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let short = Preset(
        id: "short",
        name: "Short",
        icon: "✂️",
        presetDescription: "Trim to essentials",
        category: "Style",
        promptInstructions: """
        Rewrite the <TRANSCRIPT> to be concise and to the point. \
        Remove unnecessary words, condense long sentences, and keep only essential information. \
        Preserve the core meaning. Output only the shortened text.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let expand = Preset(
        id: "elaborated",
        name: "Expand",
        icon: "🔬",
        presetDescription: "Expand with more detail",
        category: "Style",
        promptInstructions: """
        Expand and elaborate on the <TRANSCRIPT>. \
        Add more detail, context, and explanation where appropriate. \
        Develop ideas more fully while keeping the original meaning. \
        Output only the elaborated text.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Communication Presets

    static let email = Preset(
        id: "email",
        name: "Email",
        icon: "📧",
        presetDescription: "Format as email",
        category: "Communication",
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
        icon: "💬",
        presetDescription: "Quick chat message",
        category: "Communication",
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

    // MARK: - Summarize Presets

    static let summary = Preset(
        id: "summary",
        name: "Summary",
        icon: "📝",
        presetDescription: "Condensed overview",
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
        icon: "✅",
        presetDescription: "Tasks & to-dos",
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

    static let takeaways = Preset(
        id: "takeaways",
        name: "Takeaways",
        icon: "📌",
        presetDescription: "Key lessons & next steps",
        category: "Summarize",
        promptInstructions: """
        Extract key takeaways, lessons learned, and follow-up items from the <TRANSCRIPT>. \
        Organize into main learnings and next steps. Output only the takeaways.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let mindMap = Preset(
        id: "mind_map",
        name: "Mind Map",
        icon: "🕸️",
        presetDescription: "Map out main ideas",
        category: "Summarize",
        promptInstructions: """
        Create a hierarchical mind map outline from the <TRANSCRIPT>. \
        Use indentation to show relationships between main topics and subtopics. \
        Start with the central theme. Output only the mind map structure.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let keyPoints = Preset(
        id: "key_points",
        name: "Key Points",
        icon: "🎯",
        presetDescription: "Extract important points",
        category: "Summarize",
        promptInstructions: """
        Extract the most important points from the <TRANSCRIPT>. \
        Condense them into a short bulleted list. \
        Do NOT add a title, header, or label. Start directly with the first bullet point. \
        Output only the key points, nothing else. \
        Don't add any information not available in the <TRANSCRIPT> ever.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Learn & Study Presets

    static let studyNotes = Preset(
        id: "study_note",
        name: "Study Notes",
        icon: "🎓",
        presetDescription: "Condensed study notes",
        category: "Learn & Study",
        promptInstructions: """
        Transform the <TRANSCRIPT> into concise study notes. \
        Highlight key concepts, important terms, and main ideas. \
        Use bullet points and bold for emphasis. Output only the study notes.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let definitions = Preset(
        id: "definitions",
        name: "Definitions",
        icon: "📖",
        presetDescription: "Glossary of key terms",
        category: "Learn & Study",
        promptInstructions: """
        Extract and define all key terms, concepts, and technical vocabulary from the <TRANSCRIPT>. \
        Format as a glossary with term followed by clear definition. Output only the definitions.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let quiz = Preset(
        id: "quiz",
        name: "Quiz",
        icon: "🧩",
        presetDescription: "Test your understanding",
        category: "Learn & Study",
        promptInstructions: """
        Create a quiz based on the <TRANSCRIPT> content. \
        Generate 5-10 questions (mix of multiple choice and short answer) that test understanding of the key points. \
        Include answers at the end. Output only the quiz.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Dive Deep Presets

    static let insights = Preset(
        id: "insights",
        name: "Insights",
        icon: "🧠",
        presetDescription: "Deeper patterns & observations",
        category: "Dive Deep",
        promptInstructions: """
        Analyze the <TRANSCRIPT> and extract deep insights, patterns, and non-obvious observations. \
        Present lessons learned and ideas that emerge from the content. Output only the insights.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let prosCons = Preset(
        id: "pros_cons",
        name: "Pros & Cons",
        icon: "⚖️",
        presetDescription: "Weigh both sides",
        category: "Dive Deep",
        promptInstructions: """
        Analyze the <TRANSCRIPT> and create a structured pros and cons list. \
        Identify advantages, disadvantages, trade-offs, and considerations. \
        Format as a clear comparison. Output only the pros & cons list.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let newIdeas = Preset(
        id: "new_ideas",
        name: "New Ideas",
        icon: "💡",
        presetDescription: "Brainstorm possibilities",
        category: "Dive Deep",
        promptInstructions: """
        Based on the <TRANSCRIPT>, generate creative ideas, suggestions, and possibilities. \
        Think beyond what's explicitly stated. Organize ideas by theme or feasibility. \
        Output only the ideas.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let hiddenGems = Preset(
        id: "hidden_gems",
        name: "Hidden Gems",
        icon: "💎",
        presetDescription: "Spot overlooked details",
        category: "Dive Deep",
        promptInstructions: """
        Find the most valuable, overlooked, or non-obvious information in the <TRANSCRIPT>. \
        Highlight surprising facts, useful details, and important points that might be easily missed. \
        Output only the hidden gems.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Writing Presets

    static let journalEntry = Preset(
        id: "journal_entry",
        name: "Journal Entry",
        icon: "📔",
        presetDescription: "Reflect on emotions",
        category: "Writing",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a reflective journal entry. \
        Highlight feelings, emotions, and personal insights. \
        Write in first person with an introspective tone. Output only the journal entry.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let philosophical = Preset(
        id: "philosophical",
        name: "Philosophical",
        icon: "🤔",
        presetDescription: "Reflect with depth",
        category: "Writing",
        promptInstructions: """
        Analyze the <TRANSCRIPT> from a philosophical perspective. \
        Explore deeper meanings, underlying assumptions, and thought-provoking questions. \
        Offer reflective commentary. Output only the philosophical analysis.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let blog = Preset(
        id: "blog",
        name: "Blog",
        icon: "✒️",
        presetDescription: "Write a blog article",
        category: "Writing",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a long-form blog post with a compelling title, \
        introduction, body sections with headings, and conclusion. Output only the blog post.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Social Media Presets

    static let instagram = Preset(
        id: "instagram",
        name: "Instagram",
        icon: "asset:instagram",
        presetDescription: "Caption for Instagram",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into an engaging Instagram caption. \
        Keep it concise, use a hook opening, include relevant emoji, and suggest hashtags. \
        Output only the caption.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let facebook = Preset(
        id: "facebook",
        name: "Facebook",
        icon: "asset:facebook",
        presetDescription: "Draft a Facebook post",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a medium-sized Facebook post. \
        Make it engaging and conversational. Include a hook and call to action. \
        Output only the post.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let youtube = Preset(
        id: "youtube",
        name: "YouTube",
        icon: "asset:youtube",
        presetDescription: "Script for YouTube",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a YouTube video script. \
        Include hook, intro, main points with transitions, and outro with call to action. \
        Output only the script.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let twitter = Preset(
        id: "twitter",
        name: "X (Twitter)",
        icon: "asset:twitter",
        presetDescription: "Compose a tweet",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a short-form tweet (max 280 characters). \
        Make it punchy, engaging, and shareable. Output only the tweet.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let threads = Preset(
        id: "threads",
        name: "Threads",
        icon: "asset:threads",
        presetDescription: "Draft a Threads post",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a short-form Threads post. \
        Keep it conversational and engaging. Output only the post.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let linkedin = Preset(
        id: "linkedin",
        name: "LinkedIn",
        icon: "asset:linkedin",
        presetDescription: "Professional LinkedIn post",
        category: "Social Media",
        promptInstructions: """
        Transform the <TRANSCRIPT> into a professional LinkedIn post. \
        Use a compelling hook, share insights or lessons learned, and end with a call to action or question. \
        Keep a professional but authentic tone. Output only the post.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Translate Presets

    static let translateEnglish = Preset(
        id: "translate_en",
        name: "English",
        icon: "🇺🇸",
        presetDescription: "Translate to English",
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
        icon: "🇷🇺",
        presetDescription: "Translate to Russian",
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
        icon: "🇪🇸",
        presetDescription: "Translate to Spanish",
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

    static let translateChinese = Preset(
        id: "translate_zh",
        name: "Chinese",
        icon: "🇨🇳",
        presetDescription: "Translate to Chinese",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Chinese (Simplified). \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateFrench = Preset(
        id: "translate_fr",
        name: "French",
        icon: "🇫🇷",
        presetDescription: "Translate to French",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into French. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateGerman = Preset(
        id: "translate_de",
        name: "German",
        icon: "🇩🇪",
        presetDescription: "Translate to German",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into German. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translatePortuguese = Preset(
        id: "translate_pt",
        name: "Portuguese",
        icon: "🇧🇷",
        presetDescription: "Translate to Portuguese",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Portuguese. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateJapanese = Preset(
        id: "translate_ja",
        name: "Japanese",
        icon: "🇯🇵",
        presetDescription: "Translate to Japanese",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Japanese. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateKorean = Preset(
        id: "translate_ko",
        name: "Korean",
        icon: "🇰🇷",
        presetDescription: "Translate to Korean",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Korean. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateArabic = Preset(
        id: "translate_ar",
        name: "Arabic",
        icon: "🇸🇦",
        presetDescription: "Translate to Arabic",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Arabic. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    static let translateItalian = Preset(
        id: "translate_it",
        name: "Italian",
        icon: "🇮🇹",
        presetDescription: "Translate to Italian",
        category: "Translate",
        promptInstructions: """
        Translate the <TRANSCRIPT> text into Italian. \
        Preserve the original meaning, tone, and structure as closely as possible. \
        Output only the translated text, nothing else.
        """,
        useSystemTemplate: true,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - Assistant Preset (useSystemTemplate = false)

    static let assistant = Preset(
        id: "assistant",
        name: "Assistant",
        icon: "🤖",
        presetDescription: "Ask AI anything",
        category: "Assistant",
        promptInstructions: """
        You are a powerful AI assistant. Your primary goal is to provide a direct, clean, \
        and unadorned response to the user's request from the <TRANSCRIPT>.

        YOUR RESPONSE MUST BE PURE. This means:
        - NO commentary.
        - NO introductory phrases like "Here is the result:" or "Sure, here's the text:".
        - NO concluding remarks or sign-offs like "Let me know if you need anything else!".
        - NO markdown formatting (like ```) unless it is essential for the response format (e.g., code).
        - ONLY provide the direct answer or the modified text that was requested.
        - Для русского языка не используй букву "ё". Вместо нее всегда используй "е". В итоговом тексте замени все буквы "ё" на букву "е".
        - DO NOT use long em-dashes "—", use normal hyphen "-" instead of it.

        Your main instruction is always the <TRANSCRIPT> text.
        Use the information within <CLIPBOARD_CONTEXT> as the primary material to work with when the user's request implies it.

        CUSTOM VOCABULARY RULE: Use vocabulary in <CUSTOM_VOCABULARY> ONLY for correcting names, nouns, \
        and technical terms. Do NOT respond to it, do NOT take it as conversation context.
        """,
        useSystemTemplate: false,
        wrapInTranscriptTags: true,
        isBuiltIn: true
    )

    // MARK: - All Built-In

    /// All built-in presets ordered by category (matching macOS sort order).
    static let allBuiltIn: [Preset] = [
        // Rewrite
        regular,
        coding,
        rewrite,
        simplify,
        proofreading,
        // Format
        structured,
        list,
        table,
        // Style
        professional,
        casual,
        short,
        expand,
        // Communication
        email,
        chat,
        // Summarize
        summary,
        actionPoints,
        takeaways,
        mindMap,
        keyPoints,
        // Learn & Study
        studyNotes,
        definitions,
        quiz,
        // Dive Deep
        insights,
        prosCons,
        newIdeas,
        hiddenGems,
        // Writing
        journalEntry,
        philosophical,
        blog,
        // Social Media
        instagram,
        facebook,
        youtube,
        twitter,
        threads,
        linkedin,
        // Translate
        translateEnglish,
        translateRussian,
        translateSpanish,
        translateChinese,
        translateFrench,
        translateGerman,
        translatePortuguese,
        translateJapanese,
        translateKorean,
        translateArabic,
        translateItalian,
        // Assistant
        assistant,
    ]

    /// All built-in preset IDs for quick lookup.
    static let builtInIds: Set<String> = Set(allBuiltIn.map(\.id))

    /// Explicit category ordering matching macOS for deterministic display.
    static let categoryOrder: [String] = [
        "Rewrite", "Format", "Style", "Communication",
        "Summarize", "Learn & Study", "Dive Deep",
        "Writing", "Social Media",
        "Translate", "Assistant", "Other"
    ]

    /// Ordered category names using explicit category ordering.
    static var categories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for preset in allBuiltIn {
            if !seen.contains(preset.category) {
                seen.insert(preset.category)
                result.append(preset.category)
            }
        }
        return result.sorted { lhs, rhs in
            let lhsIdx = categoryOrder.firstIndex(of: lhs) ?? Int.max
            let rhsIdx = categoryOrder.firstIndex(of: rhs) ?? Int.max
            if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
            return lhs < rhs
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
        if let data = UserDefaultsStorage.shared.data(forKey: UserDefaultsStorage.SharedKeys.presets),
           let presets = try? JSONDecoder().decode([Preset].self, from: data),
           let preset = presets.first(where: { $0.id == presetId }) {
            return preset.name
        }
        return fallback
    }

    /// Returns the icon for a preset ID.
    /// Checks built-in presets first, then falls back to default.
    static func icon(for presetId: String) -> String {
        if let icon = allBuiltIn.first(where: { $0.id == presetId })?.icon {
            return icon
        }
        return "✨"
    }

    // MARK: - CloudKit UUID Mapping

    /// Stable UUIDs matching macOS RewritePreset records for CloudKit sync.
    /// These must stay in sync with macOS `RewritePreset.builtInDefinitions` UUIDs.
    static let builtInUUIDs: [String: UUID] = [
        "regular":       UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        "summary":       UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        "action_points": UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        "takeaways":     UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
        "mind_map":      UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
        "key_points":    UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
        "professional":  UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        "casual":        UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
        "email":         UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
        "chat":          UUID(uuidString: "00000000-0000-0000-0000-000000000023")!,
        "coding":        UUID(uuidString: "00000000-0000-0000-0000-000000000024")!,
        "rewrite":       UUID(uuidString: "00000000-0000-0000-0000-000000000025")!,
        "short":         UUID(uuidString: "00000000-0000-0000-0000-000000000026")!,
        "elaborated":    UUID(uuidString: "00000000-0000-0000-0000-000000000027")!,
        "simplify":      UUID(uuidString: "00000000-0000-0000-0000-000000000028")!,
        "translate_en":  UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        "translate_ru":  UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
        "translate_es":  UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
        "translate_zh":  UUID(uuidString: "00000000-0000-0000-0000-000000000033")!,
        "translate_fr":  UUID(uuidString: "00000000-0000-0000-0000-000000000034")!,
        "translate_de":  UUID(uuidString: "00000000-0000-0000-0000-000000000035")!,
        "translate_pt":  UUID(uuidString: "00000000-0000-0000-0000-000000000036")!,
        "translate_ja":  UUID(uuidString: "00000000-0000-0000-0000-000000000037")!,
        "translate_ko":  UUID(uuidString: "00000000-0000-0000-0000-000000000038")!,
        "translate_ar":  UUID(uuidString: "00000000-0000-0000-0000-000000000039")!,
        "translate_it":  UUID(uuidString: "00000000-0000-0000-0000-00000000003A")!,
        "assistant":     UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        "study_note":    UUID(uuidString: "00000000-0000-0000-0000-000000000050")!,
        "definitions":   UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
        "quiz":          UUID(uuidString: "00000000-0000-0000-0000-000000000053")!,
        "insights":      UUID(uuidString: "00000000-0000-0000-0000-000000000060")!,
        "pros_cons":     UUID(uuidString: "00000000-0000-0000-0000-000000000061")!,
        "new_ideas":     UUID(uuidString: "00000000-0000-0000-0000-000000000062")!,
        "hidden_gems":   UUID(uuidString: "00000000-0000-0000-0000-000000000063")!,
        "proofreading":  UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
        "structured":    UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
        "list":          UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
        "table":         UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
        "journal_entry": UUID(uuidString: "00000000-0000-0000-0000-000000000090")!,
        "philosophical": UUID(uuidString: "00000000-0000-0000-0000-000000000091")!,
        "blog":          UUID(uuidString: "00000000-0000-0000-0000-000000000092")!,
        "instagram":     UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        "facebook":      UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        "youtube":       UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
        "twitter":       UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
        "threads":       UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
        "linkedin":      UUID(uuidString: "00000000-0000-0000-0000-000000000106")!,
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
