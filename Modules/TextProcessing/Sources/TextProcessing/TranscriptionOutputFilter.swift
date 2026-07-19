//
//  TranscriptionOutputFilter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.06
//

import Foundation
import os

public struct TranscriptionOutputFilter {
    private static let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "TranscriptionOutputFilter")

    private static let hallucinationPatterns = [
        #"\[.*?\]"#,     // []
        #"\(.*?\)"#,     // ()
        #"\{.*?\}"#      // {}
    ]

    /// Hesitation sounds that have no real-word collisions in any language.
    /// Always stripped regardless of language.
    ///
    /// "um" is NOT universal: it's a core German preposition ("um zu", "um 10 Uhr")
    /// and the Portuguese indefinite article ("um homem"), so it lives in the
    /// per-language lists below instead.
    private static let universalFillers = [
        "uh", "uhm", "umm", "uhh", "uhhh",
        "hmm", "hm", "mmm", "mm", "mh"
    ]

    /// Per-language fillers that may collide with real words in *other* languages
    /// and are therefore only stripped when the transcript's language is known
    /// (either explicitly via the mode or detected with high confidence).
    private static let fillersByLanguage: [String: [String]] = [
        "en": ["um", "ah", "eh", "ehh", "ha"],
        "ru": ["um", "ээ", "эээ", "ээээ", "э-э", "э-э-э", "эм", "эмм", "ыы", "ыыы"],
        "es": ["um", "ehm", "ehmm", "eee", "eeh"],
        "de": ["äh", "ähm", "ähh", "ähhh", "ähmm", "öh", "öhm"],
        "fr": ["um", "euh", "euhh", "euhhh", "euhm", "heu", "heuu"]
    ]

    /// Returns true if the text contains meaningful content for a transcription.
    /// Returns false for empty strings, whitespace-only strings, or strings containing only punctuation.
    public static func hasMeaningfulContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Check if there's at least one alphanumeric character
        return trimmed.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
    }

    /// Strip known hallucination markers and filler words from a transcript.
    ///
    /// - Parameters:
    ///   - text: Raw transcript output.
    ///   - language: ISO 639-1 code from the active mode (e.g. "en", "ru") or "auto"/nil.
    ///     When unspecified or "auto", `NLLanguageRecognizer` is used; if detection
    ///     also fails, English is the final fallback.
    ///   - removeFillers: When false, hesitation sounds are kept verbatim. Hallucination
    ///     markers (bracketed segments, tag blocks) are stripped either way.
    public static func filter(_ text: String, language: String? = nil, removeFillers: Bool = true) -> String {
        var filteredText = text

        // Remove <TAG>...</TAG> blocks
        let tagBlockPattern = #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: tagBlockPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove bracketed hallucinations
        for pattern in hallucinationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Resolve language, pick filler set, and remove filler words.
        let fillerLanguage: String
        if removeFillers {
            let resolvedLanguage = resolveLanguage(explicit: language, text: text) ?? "en"
            fillerLanguage = resolvedLanguage
            var fillers = universalFillers
            if let extras = fillersByLanguage[resolvedLanguage] {
                fillers.append(contentsOf: extras)
            }

            for fillerWord in fillers {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(filteredText.startIndex..., in: filteredText)
                    filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
                }
            }
        } else {
            fillerLanguage = "off"
        }

        // Clean whitespace while preserving intentional line breaks.
        filteredText = filteredText.replacingOccurrences(of: "\r\n", with: "\n")
        filteredText = filteredText.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.replacingOccurrences(of: #" *\n *"#, with: "\n", options: .regularExpression)
        filteredText = filteredText.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Log results
        if filteredText != text {
            logger.notice("📝 Output filter (\(fillerLanguage, privacy: .public)) result: \(filteredText, privacy: .public)")
        } else {
            logger.notice("📝 Output filter (\(fillerLanguage, privacy: .public)) result (unchanged): \(filteredText, privacy: .public)")
        }

        return filteredText
    }

    /// Strips any number of trailing periods from the transcript so casual
    /// messages like "Okay." or "Wait..." don't read as cold or trailing-off
    /// in chat contexts.
    ///
    /// Only the tail is touched: leading and internal whitespace are preserved,
    /// internal periods (acronyms, mid-sentence) are kept, and "?" / "!" carry
    /// their own meaning so they pass through unchanged.
    public static func stripTrailingPeriods(_ text: String) -> String {
        var view = Substring(text)
        // Skip past any trailing whitespace so "Okay.   " is still recognized.
        while let last = view.last, last.isWhitespace {
            view = view.dropLast()
        }
        guard view.last == "." else { return text }
        while view.last == "." {
            view = view.dropLast()
        }
        return String(view)
    }

    /// Resolves the language code used to pick the filler set.
    ///
    /// Order of preference:
    /// 1. Explicit, non-"auto" mode language (region suffixes are stripped: "en-US" → "en").
    /// 2. `NLLanguageRecognizer` over the raw transcript.
    /// 3. nil (caller falls back to English).
    private static func resolveLanguage(explicit: String?, text: String) -> String? {
        if let explicit, !explicit.isEmpty, explicit.lowercased() != "auto" {
            let primary = explicit.split(separator: "-").first.map(String.init) ?? explicit
            return primary.lowercased()
        }
        return LanguageDetector.detect(text)
    }
}
