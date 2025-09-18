//
//  WhisperHallucinationFilter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.06
//

import Foundation
import os

actor WhisperHallucinationFilter {
    private static let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "WhisperHallucinationFilter")
    
    private static let hallucinationPatterns = [
        #"\[.*?\]"#,     // []
        #"\(.*?\)"#,     // ()
        #"\{.*?\}"#      // {}
    ]

    private static let fillerWords = [
        "uh", "um", "uhm", "umm", "uhh", "uhhh", "er", "ah", "eh",
        "hmm", "hm", "mmm", "mm", "mh", "ha", "ehh"
    ]
    static func filter(_ text: String) -> String {
        logger.notice("🧹 Filtering hallucinations and filler words")
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

        // Remove filler words
        for fillerWord in fillerWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Clean whitespace
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Log results
        if filteredText != text {
            logger.notice("✅ Removed hallucinations and filler words")
        } else {
            logger.notice("✅ No hallucinations or filler words found")
        }

        return filteredText
    }
}
