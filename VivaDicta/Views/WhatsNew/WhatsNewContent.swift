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
    var tagline: String?
    var learnMoreURL: URL?
    var learnMoreTitle: String?
}

enum WhatsNewCatalog {
    static func release(for version: String) -> WhatsNewRelease? {
        let majorMinor = version.split(separator: ".").prefix(2).joined(separator: ".")
        return releases[majorMinor]
    }

    private static let releases: [String: WhatsNewRelease] = [
        "3.7": release_3_7,
        "3.6": release_3_6,
        "3.5": release_3_5,
        "3.4": release_3_4,
        "3.3": release_3_3,
        "3.2": release_3_2,
        "3.1": release_3_1,
        "3.0": release_3_0,
        "2.0": release_2_0,
        "2.1": release_2_1,
        "2.2": release_2_2
    ]

    private static let release_3_7 = WhatsNewRelease(
        id: "3.7",
        headline: "What's New in VivaDicta 3.7.0",
        features: [
            WhatsNewFeature(
                icon: "cpu.fill",
                iconColors: [.purple, .indigo],
                title: "On-Device LLM Processing",
                description: "Download an on-device LLM and process your text fully offline - no API key, fully private. Now works on more devices, including many on iOS 18 without Apple Intelligence."
            ),
            WhatsNewFeature(
                icon: "cloud.fill",
                iconColors: [.teal, .cyan],
                title: "OpenCode Zen & Go",
                description: "Two new cloud AI providers. OpenCode Zen includes free models you can try with just a free API key - no payment method needed."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.yellow, .orange],
                title: "Quality of Life",
                description: "Ollama Cloud now marks free vs subscription models, the custom AI provider screen scrolls fully, plus stability fixes."
            )
        ],
        tagline: "On-device LLM processing, now on more devices."
    )

    private static let release_3_6 = WhatsNewRelease(
        id: "3.6",
        headline: "What's New in VivaDicta 3.6.0",
        features: [
            WhatsNewFeature(
                icon: "person.2.wave.2.fill",
                iconColors: [.teal, .cyan],
                title: "Speaker Labels for ElevenLabs & xAI",
                description: "Turn on Speaker Labels and these two cloud providers now return speaker-separated transcripts, so it's clear who said what."
            ),
            WhatsNewFeature(
                icon: "keyboard.fill",
                iconColors: [.purple, .pink],
                title: "Clearer Keyboard Return",
                description: "When the keyboard needs you to swipe back to finish dictating, a full-screen prompt now makes the next step obvious."
            ),
            WhatsNewFeature(
                icon: "doc.on.doc.fill",
                iconColors: [.indigo, .blue],
                title: "Copy from Live Translation",
                description: "New copy buttons on each Live Translation column let you grab the original or the translated text with one tap."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.yellow, .orange],
                title: "Performance & Polish",
                description: "Cleaner filler removal on translated notes, faster Live Translation startup, and a fix for a rare background-transcription crash."
            )
        ],
        tagline: "Clearer transcripts, smoother dictation."
    )

    private static let release_3_5 = WhatsNewRelease(
        id: "3.5",
        headline: "What's New in VivaDicta 3.5.0",
        features: [
            WhatsNewFeature(
                icon: "waveform.badge.plus",
                iconColors: [.green, .mint],
                title: "AssemblyAI Transcription",
                description: "New cloud transcription provider with high accuracy, speaker labels, and broad language support. Add your AssemblyAI API key in Settings to try it."
            ),
            WhatsNewFeature(
                icon: "cloud.fill",
                iconColors: [.blue, .cyan],
                title: "Ollama Cloud",
                description: "Run Ollama's hosted AI models without your own server. Just add an API key - separate from the existing local Ollama option."
            ),
            WhatsNewFeature(
                icon: "cpu.fill",
                iconColors: [.purple, .indigo],
                title: "MiniMax AI",
                description: "New AI processing provider. Add your MiniMax API key in Settings to clean up and rewrite your text with its M-series models."
            ),
            WhatsNewFeature(
                icon: "circle.hexagongrid.fill",
                iconColors: [.pink, .orange],
                title: "Recording Orb",
                description: "Choose your recording visualization: Particles, ASCII, or None. Plus a lighter, smoother orb that won't bog down busy devices."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.yellow, .orange],
                title: "Quality of Life",
                description: "The app version now shows at the bottom of Settings, and a round of polish across the app."
            )
        ],
        tagline: "More ways to transcribe, process, and personalize."
    )

    private static let release_3_4 = WhatsNewRelease(
        id: "3.4",
        headline: "What's New in VivaDicta 3.4.0",
        features: [
            WhatsNewFeature(
                icon: "tag.fill",
                iconColors: [.orange, .yellow],
                title: "Tag While You Record",
                description: "Add tags right from the recording sheet, so notes land already organized. The active filter carries over when you start a recording."
            ),
            WhatsNewFeature(
                icon: "waveform.badge.plus",
                iconColors: [.green, .mint],
                title: "xAI Speech-to-Text",
                description: "New cloud transcription provider powered by Grok. Add your xAI API key in Settings to try it."
            ),
            WhatsNewFeature(
                icon: "globe.americas.fill",
                iconColors: [.indigo, .cyan],
                title: "Live Translation Save Options",
                description: "Saving a Live Translation as a note now lets you choose what to keep: both languages, source only, or target only."
            ),
            WhatsNewFeature(
                icon: "wand.and.stars",
                iconColors: [.purple, .indigo],
                title: "Default AI Mode",
                description: "Pick a fallback AI mode so AI Actions are ready on every note, even when the current mode has no AI configured."
            ),
            WhatsNewFeature(
                icon: "slider.horizontal.3",
                iconColors: [.pink, .purple],
                title: "Make It Yours",
                description: "New Advanced toggles let you hide Chats and Live Translation if you don't use them, and Trim Trailing Period is now a single global setting."
            ),
            WhatsNewFeature(
                icon: "cpu.fill",
                iconColors: [.blue, .indigo],
                title: "Latest AI Models",
                description: "Added Claude Opus 4.8, refreshed the Grok, Z.AI, Kimi, and Gemini lineups, and removed retired models."
            )
        ],
        tagline: "Tag as you talk. Make VivaDicta yours."
    )

    private static let release_3_3 = WhatsNewRelease(
        id: "3.3",
        headline: "What's New in VivaDicta 3.3.0",
        features: [
            WhatsNewFeature(
                icon: "globe",
                iconColors: [.indigo, .cyan],
                title: "Multi-Language Keyboard",
                description: "Type in your language. New French, German, Spanish, and Russian layouts, with cycling between EN and your active languages."
            ),
            WhatsNewFeature(
                icon: "waveform.badge.plus",
                iconColors: [.green, .mint],
                title: "Cartesia Transcription",
                description: "New cloud transcription provider with fast, high-accuracy results. Add your Cartesia API key in Settings to try it."
            ),
            WhatsNewFeature(
                icon: "folder.badge.plus",
                iconColors: [.orange, .yellow],
                title: "Auto Export to Folder",
                description: "Pick a folder once and every new transcription is exported there as markdown. New Export Settings screen with one-tap manual export."
            ),
            WhatsNewFeature(
                icon: "paperplane.fill",
                iconColors: [.purple, .indigo],
                title: "Send to Obsidian Button",
                description: "Send any single transcription to Obsidian on demand from the detail view, even when auto-append is off."
            ),
            WhatsNewFeature(
                icon: "slider.horizontal.below.rectangle",
                iconColors: [.pink, .purple],
                title: "Temporary Mode Override",
                description: "Pick a different AI mode just for one transcription right from the AI Actions sheet, without changing your default."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.blue, .indigo],
                title: "Quality of Life",
                description: "Auto-enable keyboard languages from iOS preferences, tighter recording sheet layout, refined HUD contrast, and small polish across Settings."
            ),
        ],
        tagline: "Dictation, in your language."
    )

    private static let release_3_2 = WhatsNewRelease(
        id: "3.2",
        headline: "What's New in VivaDicta 3.2",
        features: [
            WhatsNewFeature(
                icon: "globe.americas.fill",
                iconColors: [.indigo, .cyan],
                title: "Live Translation",
                description: "Your own personal interpreter. Speak in one language and hear it in another in near real time. Plug in headphones, pick from 60+ languages, and adjust playback speed."
            ),
            WhatsNewFeature(
                icon: "text.bubble.fill",
                iconColors: [.purple, .indigo],
                title: "Translate While You Transcribe",
                description: "With Soniox, Gladia, or Speechmatics selected, pick a target language in the new \"Translate to\" picker. Your transcription comes back already translated, no extra AI step needed."
            ),
            WhatsNewFeature(
                icon: "waveform.badge.plus",
                iconColors: [.green, .mint],
                title: "Two New Cloud Transcription Providers",
                description: "Gladia Solaria (100+ languages, speaker labels, inline translation) and Speechmatics Enhanced (top accuracy on European languages, with translation built in)."
            ),
            WhatsNewFeature(
                icon: "arrow.up.forward.app.fill",
                iconColors: [.purple, .indigo],
                title: "Save to Obsidian Automatically",
                description: "Turn on Append to Obsidian in any mode and each transcription opens Obsidian with a new note. One note per transcription with timestamped filenames, or pile them into a daily note."
            ),
            WhatsNewFeature(
                icon: "checklist",
                iconColors: [.orange, .yellow],
                title: "Reminders in Original Language",
                description: "Extract Reminders now keeps the language of your note. German notes produce German reminders, Russian notes produce Russian reminders, instead of occasionally being translated to English."
            ),
            WhatsNewFeature(
                icon: "text.badge.minus",
                iconColors: [.orange, .pink],
                title: "Trim Trailing Period",
                description: "New per-mode toggle that strips a trailing \".\" or \"...\" from the final transcript. Helpful for casual messages where \"Okay.\" can read as cold. \"!\" and \"?\" are kept."
            ),
            WhatsNewFeature(
                icon: "character.book.closed.fill",
                iconColors: [.teal, .green],
                title: "Multilingual Filler Filtering",
                description: "Filler words like \"uh\", \"um\", and \"hmm\" are now also stripped in Russian (ээ, э-э, эм), Spanish (ehm), German (äh, ähm), and French (euh)."
            ),
            WhatsNewFeature(
                icon: "cpu.fill",
                iconColors: [.pink, .purple],
                title: "Latest AI Models",
                description: "Added Anthropic Claude Opus 4.7 and OpenAI GPT-5.5 (now the default for OpenAI)."
            ),
        ],
        tagline: "Speak any language. Hear it back in another.",
        learnMoreURL: URL(string: "https://vivadicta.com/ios/docs/live-translation"),
        learnMoreTitle: "Learn more about Live Translation"
    )

    private static let release_3_1 = WhatsNewRelease(
        id: "3.1",
        headline: "What's New in VivaDicta 3.1",
        features: [
            WhatsNewFeature(
                icon: "keyboard.fill",
                iconColors: [.pink, .orange],
                title: "AZERTY Keyboard",
                description: "New French AZERTY layout with proper callouts and accented characters. Enable in Settings > Keyboard."
            ),
            WhatsNewFeature(
                icon: "rectangle.3.group.fill",
                iconColors: [.orange, .pink],
                title: "Home Screen Widgets",
                description: "New Ask & Record and Quick Actions widgets put recording, chat, and search one tap away from your home screen."
            ),
            WhatsNewFeature(
                icon: "app.badge.checkmark.fill",
                iconColors: [.green, .mint],
                title: "Shortcuts & Spotlight",
                description: "New Start, Stop, Cancel, and Record-and-return shortcut actions, plus a Find Notes action and Spotlight integration for Search and Ask AI."
            ),
            WhatsNewFeature(
                icon: "bubble.left.and.bubble.right.fill",
                iconColors: [.blue, .cyan],
                title: "All Notes Chat",
                description: "Chat across your entire library without picking individual notes. Ask broad questions and get grounded answers."
            ),
            WhatsNewFeature(
                icon: "person.badge.key.fill",
                iconColors: [.purple, .pink],
                title: "Chat with AI Accounts",
                description: "Chat now works with OpenAI and Gemini sign-in - no API key needed."
            ),
            WhatsNewFeature(
                icon: "arrow.up.doc.fill",
                iconColors: [.indigo, .blue],
                title: "Markdown Export",
                description: "Export single notes as Markdown from the share menu, with a content setting to control what's included."
            ),
            WhatsNewFeature(
                icon: "hand.tap.fill",
                iconColors: [.teal, .cyan],
                title: "Quick Actions",
                description: "Long-press the app icon for instant Search, Ask AI, and Need help shortcuts."
            ),
        ],
        tagline: "Notes and AI, always one tap away."
    )

    private static let release_3_0 = WhatsNewRelease(
        id: "3.0",
        headline: "What's New in VivaDicta 3.0",
        features: [
            WhatsNewFeature(
                icon: "bubble.left.and.text.bubble.right.fill",
                iconColors: [.blue, .cyan],
                title: "Chat With Your Notes",
                description: "Ask questions about one note or many. Surface insights, action items, and key points, or connect ideas across recordings. Powered by Apple Foundation Model on-device or your favorite cloud AI."
            ),
            WhatsNewFeature(
                icon: "magnifyingglass.circle.fill",
                iconColors: [.green, .mint],
                title: "Smart AI Search",
                description: "Find notes by meaning, not just keywords. Ask \"what did I say about the pricing idea?\" and VivaDicta finds it - even without those exact words. Fully on-device, so your data stays private."
            ),
            WhatsNewFeature(
                icon: "globe.badge.chevron.backward",
                iconColors: [.indigo, .blue],
                title: "Chat Search Tools",
                description: "Chat comes with built-in tools: cross-note AI search across your library and live web search, so answers stay grounded in real context."
            ),
            WhatsNewFeature(
                icon: "person.2.wave.2.fill",
                iconColors: [.teal, .cyan],
                title: "Speaker Labels",
                description: "Get speaker-separated transcripts for conversations, plus real Parakeet progress and stronger handling for long recordings."
            ),
            WhatsNewFeature(
                icon: "checklist.checked",
                iconColors: [.orange, .yellow],
                title: "Reminder Suggestions",
                description: "Turn notes into reminder suggestions, review them, and send approved items straight to Apple Reminders."
            ),
            WhatsNewFeature(
                icon: "square.and.arrow.up",
                iconColors: [.pink, .orange],
                title: "Quality of Life",
                description: "Export notes to Markdown, append follow-up recordings to existing notes, and hide presets you don't use to keep pickers focused."
            ),
            WhatsNewFeature(
                icon: "sparkles",
                iconColors: [.purple, .pink],
                title: "Liquid Glass Design",
                description: "Enjoy a more polished iOS 26 interface with Liquid Glass, plus refreshed recording controls on the keyboard and Apple Watch."
            )
        ],
        tagline: "Dictate anywhere. Now talk to your notes.",
        learnMoreURL: URL(string: "https://vivadicta.com/ios/docs/chats"),
        learnMoreTitle: "Learn more about Chats & Smart Search"
    )

    private static let release_2_2 = WhatsNewRelease(
        id: "2.2",
        headline: "What's New in VivaDicta 2.2",
        features: [
            WhatsNewFeature(
                icon: "applewatch",
                iconColors: [.orange, .yellow],
                title: "Apple Watch App",
                description: "Record voice notes on your wrist. Recordings are sent to iPhone for transcription automatically."
            ),
            WhatsNewFeature(
                icon: "dial.medium",
                iconColors: [.green, .mint],
                title: "Watch Modes",
                description: "Switch between Viva Modes on the watch for different transcription and AI processing settings."
            ),
            WhatsNewFeature(
                icon: "watchface.applewatch.case",
                iconColors: [.blue, .cyan],
                title: "Complications & Action Button",
                description: "Add to your watch face for one-tap recording, or assign the Action Button to start and stop."
            ),
            WhatsNewFeature(
                icon: "iphone.and.arrow.right.inward",
                iconColors: [.purple, .pink],
                title: "iPhone Control on Watch",
                description: "Start and stop iPhone recording from your wrist via Control Center, Smart Stack, or Action Button."
            ),
            WhatsNewFeature(
                icon: "arrow.trianglehead.2.clockwise.rotate.90.icloud",
                iconColors: [.cyan, .blue],
                title: "Background Transcription",
                description: "Watch recordings are transcribed in the background - notes are ready when you open the app."
            )
        ],
        learnMoreURL: URL(string: "https://vivadicta.com/ios/docs/watch-general-usage"),
        learnMoreTitle: "Learn more about VivaDicta Watch app"
    )

    private static let release_2_1 = WhatsNewRelease(
        id: "2.1",
        headline: "What's New in VivaDicta 2.1",
        features: [
            WhatsNewFeature(
                icon: "keyboard.badge.ellipsis",
                iconColors: [.purple, .pink],
                title: "Keyboard AI Processing",
                description: "Process text directly from the VivaDicta keyboard. Translate, rewrite, or summarize in any app."
            ),
            WhatsNewFeature(
                icon: "doc.on.clipboard",
                iconColors: [.teal, .cyan],
                title: "Keyboard Recent Notes",
                description: "Quickly insert recent transcriptions from the keyboard without opening the app."
            ),
            WhatsNewFeature(
                icon: "person.badge.key",
                iconColors: [.blue, .indigo],
                title: "AI Accounts",
                description: "Use your OpenAI, Gemini, or Copilot accounts — no API keys needed."
            ),
            WhatsNewFeature(
                icon: "waveform.badge.plus",
                iconColors: [.green, .mint],
                title: "Cohere Transcription",
                description: "New cloud provider with best-in-class accuracy across 14 languages. Free trial included."
            ),
            WhatsNewFeature(
                icon: "tag",
                iconColors: [.orange, .yellow],
                title: "Tags & Organization",
                description: "Create custom tags with colors and icons. Auto-track where each note came from — app, keyboard, extension, or Mac."
            ),
            WhatsNewFeature(
                icon: "globe",
                iconColors: [.cyan, .blue],
                title: "New Translation Presets",
                description: "Eight new languages: Chinese, French, German, Portuguese, Japanese, Korean, Arabic, and Italian."
            ),
            WhatsNewFeature(
                icon: "pencil.and.outline",
                iconColors: [.pink, .orange],
                title: "Quality of Life",
                description: "Edit notes directly, improved mode validation feedback, and various keyboard enhancements."
            )
        ]
    )

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
