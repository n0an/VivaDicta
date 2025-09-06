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
    
    // Pattern-based approach for detecting hallucinations - focusing on format indicators
    private static let hallucinationPatterns = [
        // Text in various types of brackets - the most reliable hallucination indicators
        #"\[.*?\]"#,                  // [Text in square brackets]
        #"\(.*?\)"#,                  // (Text in parentheses)
        #"\{.*?\}"#,                  // {Text in curly braces}
        #"<.*?>"#,                    // <Text in angle brackets>
        
        // Text with special formatting
        #"\*.*?\*"#,                  // *Text with asterisks*
        #"_.*?_"#,                    // _Text with underscores_
        
        // Time indicators often added by Whisper
        #"(?i)\d{1,2}:\d{2}(:\d{2})?\s*-\s*\d{1,2}:\d{2}(:\d{2})?"#  // 00:00 - 00:00 format
    ]
    
    /// Removes hallucinations from transcription text using pattern matching
    /// - Parameter text: Original transcription text from Whisper
    /// - Returns: Filtered text with hallucinations removed
    static func filter(_ text: String) -> String {
        logger.notice("🧹 Applying pattern-based hallucination filter to transcription")
        print("=== unfiltered text = \(text)")
        var filteredText = text
        
        // Remove pattern-based hallucinations
        for pattern in hallucinationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
            }
        }
        
        // Clean up extra whitespace and newlines that might be left after removing hallucinations
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add logging to track effectiveness
        if filteredText != text {
            logger.notice("✅ Removed hallucinations using pattern matching")
        } else {
            logger.notice("✅ No hallucinations detected with pattern matching")
        }
        
        return filteredText
    }
}
