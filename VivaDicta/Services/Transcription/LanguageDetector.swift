//
//  LanguageDetector.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.29
//

import Foundation
import NaturalLanguage

/// Lightweight wrapper around `NLLanguageRecognizer` for transcript text.
enum LanguageDetector {
    /// Detect the dominant language of `text` and return its ISO 639-1 code (e.g. "en", "ru").
    ///
    /// Returns nil when:
    /// - the text is shorter than `minLength` characters (signal too weak)
    /// - no hypothesis meets the confidence threshold
    static func detect(_ text: String, minLength: Int = 12, minConfidence: Double = 0.5) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minLength else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let best = hypotheses.max(by: { $0.value < $1.value }),
              best.value >= minConfidence else {
            return nil
        }
        return best.key.rawValue
    }
}
