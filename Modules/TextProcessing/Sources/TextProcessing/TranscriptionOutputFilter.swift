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
        #"\{.*?\}"#,     // {}
        // Whisper's own special and timestamp tokens: `<|startoftranscript|>`,
        // `<|ru|>`, `<|transcribe|>`, `<|2.88|>`, `<|endoftext|>`. The decoder
        // is asked to drop these at the source, but this path also serves the
        // keyboard, Share and Action extensions, so a single missed flag should
        // not be able to put raw token text in front of a user again.
        #"<\|[^|>]{0,32}\|>"#
    ]

    /// Memorized subtitle-credit strings Whisper emits when it is handed
    /// silence or noise. They are baked into the model from uncleaned training
    /// data (subtitle files that carried their author's signature), so they
    /// arrive as confident, well-formed text rather than as garbage.
    ///
    /// Stripped **anywhere** in the transcript, not just as a whole line:
    /// `WhisperKitTranscriptionService` joins every segment with a space, so a
    /// trailing silent segment lands at the end of the same line as real
    /// speech. These strings are specific enough that a mid-sentence match is
    /// a hallucination and not something a person dictated.
    ///
    /// Matched without consulting the language, deliberately. Detection has
    /// nothing to work with on a silence-only clip, and these are long enough
    /// that cross-language collisions are not a real risk.
    private static let signatureHallucinations = [
        // ru - the DimaTorzok family. The verb varies (добавил / сделал /
        // создал / "и перевод сделал"), the name does not.
        #"Субтитры[^\n]{0,40}?DimaTorzok\.?"#,
        #"\bDimaTorzok\b\.?"#,
        #"Редактор\s+субтитров[^\n]{0,80}?Корректор\s+\S+"#,
        #"Субтитры\s+подогнал\s+«[^»]{1,40}»!?"#,
        // Same failure in other languages, same shape.
        #"Altyazı\s+M\.K\.?"#,
        #"Titulky\s+vytvořil\s+\S+"#,
        #"ترجمة\s+نانسي\s+قنقر"#
    ]

    /// Hallucinations stripped wherever they stand as a **sentence of their
    /// own**: at the start of the text or after a sentence terminator, and
    /// ending the text or closed by terminal punctuation.
    ///
    /// "Продолжение следует..." is a memorized episode outro that lands after
    /// real speech when a recording ends in silence. As a whole-transcript
    /// match it was missed in exactly that case, and nobody dictates it as a
    /// sentence. The sentence boundary keeps real speech that merely contains
    /// the words: "продолжение следует в другой раз" is untouched.
    private static let sentenceHallucinations = [
        #"Продолжение\s+следует"#
    ]

    /// Hallucinations that are ordinary phrases mid-sentence, so position is
    /// what gives them away. "Спасибо за просмотр!" inside a sentence is
    /// somebody talking; arriving as the last sentence, or as the whole
    /// transcript, it is the model filling the silence the recording ended on.
    ///
    /// Dropped in both of those positions. The trailing case is the one that
    /// actually occurs: a silent tail is appended to real speech far more often
    /// than it arrives alone. To keep real speech safe the phrase must start
    /// its own sentence - preceded by a sentence terminator or the start of the
    /// text - so "я думаю, спасибо за просмотр" is left alone.
    ///
    /// English equivalents ("Thanks for watching!", "Thank you.") are
    /// deliberately absent: this is a dictation app, and those are things
    /// people genuinely dictate on their own.
    private static let tailHallucinations = [
        #"Спасибо\s+за\s+субтитры!?"#,
        #"Спасибо\s+за\s+просмотр!?"#,
        // Also a sentence hallucination above; kept here so a silence-only
        // clip with quotes or a "?" around it is still dropped whole.
        #"Продолжение\s+следует\.{0,3}"#,
        // One sentence only: the tail sweep anchors at the end of the text,
        // so a suffix that crossed a terminator would swallow the real speech
        // that follows.
        #"Смотрите\s+продолжение[^\n.!?…]{0,60}"#,
        #"ПОДПИШИСЬ\s+НА\s+КАНАЛ!?"#,
        // All-caps sound labels the model emits over noise.
        #"(?:ВЕС[ЕЁ]ЛАЯ|СПОКОЙНАЯ|ГРУСТНАЯ|ТРЕВОЖНАЯ)\s+(?:МУЗЫКА|МЕЛОДИЯ)"#,
        #"ЛАЙ\s+СОБАК"#,
        #"ШУМ\s+ДОЖДЯ"#,
        #"ПЕРЕСТРЕЛКА"#,
        #"КАШЕЛЬ"#
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

        // Strip memorized hallucinations. Deliberately outside the
        // `removeFillers` check below: a filler is something the user actually
        // said and chose to keep, a hallucination is text they never uttered.
        // The toggle is an editorial preference about real speech, so it has
        // no say over fabricated content.
        filteredText = stripHallucinations(filteredText)

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

    /// Removes memorized subtitle-credit hallucinations.
    ///
    /// Signature strings go anywhere in the text, sentence hallucinations
    /// wherever they form a sentence of their own, and the ambiguous ones only
    /// when they are the whole transcript or its final sentence - see
    /// `tailHallucinations` for why position is the tell.
    private static func stripHallucinations(_ text: String) -> String {
        var result = text

        for pattern in signatureHallucinations {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        for pattern in sentenceHallucinations {
            // Group 1 keeps the preceding terminator. The tail is either the
            // end of the text or terminal punctuation followed by more speech.
            let sentence = #"(^|[.!?…])\s*(?:"# + pattern + #")(?:[.!…]*\s*$|[.!…]+(?=\s))"#
            guard let regex = try? NSRegularExpression(pattern: sentence, options: .caseInsensitive) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in tailHallucinations {
            let anchored = "^\\W*(?:\(pattern))\\W*$"
            guard let regex = try? NSRegularExpression(pattern: anchored, options: .caseInsensitive) else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return ""
            }
        }

        return stripTrailingHallucinations(result)
    }

    /// Strips hallucinated phrases sitting as the last sentence of otherwise
    /// real speech.
    ///
    /// Group 1 keeps the terminator that ended the real sentence, so only the
    /// fabricated tail goes. Several can stack ("Спасибо за субтитры! Спасибо
    /// за просмотр!"), and each pass exposes the next one, so the sweep repeats
    /// until nothing more matches - bounded, since a pass that changes nothing
    /// ends it.
    private static func stripTrailingHallucinations(_ text: String) -> String {
        var result = text

        for _ in 0..<tailHallucinations.count {
            let before = result

            for pattern in tailHallucinations {
                let trailing = "(^|[.!?…\\n])\\s*(?:\(pattern))[\\s.!?…]*$"
                guard let regex = try? NSRegularExpression(pattern: trailing, options: .caseInsensitive) else { continue }
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
            }

            if result == before { break }
        }

        return result
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
