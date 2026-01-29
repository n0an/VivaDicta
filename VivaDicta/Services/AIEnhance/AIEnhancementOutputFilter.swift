//
//  AIEnhancementOutputFilter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import Foundation

struct AIEnhancementOutputFilter {
    static func filter(_ text: String) -> String {
        var processedText = text

        // Step 1: Remove thinking/reasoning tags WITH their content (discard AI's chain-of-thought)
        let thinkingPatterns = [
            #"(?s)<thinking>(.*?)</thinking>"#,
            #"(?s)<think>(.*?)</think>"#,
            #"(?s)<reasoning>(.*?)</reasoning>"#
        ]

        for pattern in thinkingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(processedText.startIndex..., in: processedText)
                processedText = regex.stringByReplacingMatches(in: processedText, options: [], range: range, withTemplate: "")
            }
        }

        processedText = processedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: Unwrap any XML tags that wrap the entire text (keep content, remove wrapper)
        // e.g., <TRANSCRIPTION>text</TRANSCRIPTION> → text
        processedText = unwrapOuterXMLTags(processedText)

        return processedText
    }

    /// Unwraps XML tags that wrap the entire text content.
    /// Only unwraps if the entire text is wrapped in matching opening/closing tags.
    /// Handles nested wrappers by unwrapping iteratively.
    /// Example: `<result><transcription>text</transcription></result>` → `text`
    private static func unwrapOuterXMLTags(_ text: String) -> String {
        var result = text

        // Pattern matches text completely wrapped in XML tags:
        // - ^ and $ ensure the tags wrap the ENTIRE text
        // - ([a-zA-Z][a-zA-Z0-9_]*) captures the tag name
        // - \b[^>]* allows for attributes like <tag attr="value">
        // - (.*) captures the inner content
        // - \1 backreference ensures closing tag matches opening tag
        let pattern = #"(?s)^<([a-zA-Z][a-zA-Z0-9_]*)\b[^>]*>(.*)</\1>$"#

        // Keep unwrapping while we find wrapping tags
        while let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
              let contentRange = Range(match.range(at: 2), in: result) {
            result = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}
