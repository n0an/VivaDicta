//
//  TextFormatter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.27
//

import Foundation
import NaturalLanguage

/// Formats transcription text into readable paragraphs.
///
/// ## Algorithm Overview
///
/// The formatter splits continuous transcription text into paragraphs (chunks) separated by double newlines.
/// This improves readability for long transcriptions that would otherwise be a wall of text.
///
/// ## Chunking Strategy
///
/// Each chunk (paragraph) is built by accumulating sentences until one of these conditions is met:
///
/// 1. **Word count target reached**: Once a chunk contains ~50 words, it's considered complete.
///    This creates paragraphs of roughly equal visual weight.
///
/// 2. **Sentence limit exceeded**: If a chunk would contain more than 4 "significant" sentences
///    (sentences with 4+ words), it's trimmed to prevent overly long paragraphs.
///
/// ## Key Concepts
///
/// - **Significant sentence**: A sentence with 4 or more words. Short utterances like "Yes.", "OK.",
///   or "I see." don't count toward the sentence limit, allowing natural conversation flow.
///
/// - **Chunk trimming**: When too many significant sentences accumulate before reaching the word target,
///   the chunk is cut at the 4th significant sentence to maintain paragraph balance.
///
/// ## Example
///
/// Input: "Hello. Yes. This is a longer sentence about something important. Another detailed point here.
///         I agree. The third major idea in this discussion. And finally the fourth significant statement."
///
/// Output (chunked):
/// ```
/// Hello. Yes. This is a longer sentence about something important. Another detailed point here.
///
/// I agree. The third major idea in this discussion. And finally the fourth significant statement.
/// ```
///
/// Note: "Hello.", "Yes.", and "I agree." don't count as significant sentences.
struct TextFormatter {

    // MARK: - Configuration

    /// Target word count per paragraph. Chunks are built until this threshold is reached.
    private static let targetWordCount = 50

    /// Maximum number of significant sentences (4+ words) allowed per chunk.
    /// Prevents paragraphs from becoming too long even if word count isn't reached.
    private static let maxSentencesPerChunk = 4

    /// Minimum words for a sentence to be considered "significant".
    /// Short responses like "Yes.", "OK.", "I see." don't count toward sentence limits.
    private static let minWordsForSignificantSentence = 4

    // MARK: - Public API

    /// Formats text into readable paragraphs separated by double newlines.
    ///
    /// - Parameter text: Raw transcription text to format.
    /// - Returns: Formatted text with paragraphs, or empty string if input is empty.
    static func format(_ text: String) -> String {
        let detectedLanguage = NLLanguageRecognizer.dominantLanguage(for: text)
        let tokenizerLanguage = detectedLanguage ?? .english

        // Reusable tokenizers - created once, reused for all sentences
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(tokenizerLanguage)

        let wordTokenizer = NLTokenizer(unit: .word)
        wordTokenizer.setLanguage(tokenizerLanguage)

        var allSentences = [String]()
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { sentenceRange, _ in
            let rawSentence = String(text[sentenceRange])
            allSentences.append(rawSentence.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }

        guard !allSentences.isEmpty else {
            return ""
        }

        // Pre-compute word counts for all sentences (avoids repeated tokenization)
        let wordCounts = allSentences.map { countWords(in: $0, using: wordTokenizer) }

        var chunks = [String]()
        var processedIndex = 0

        while processedIndex < allSentences.count {
            var tentativeSentences = [(sentence: String, wordCount: Int)]()
            var chunkWordCount = 0
            var significantSentenceCount = 0

            for i in processedIndex..<allSentences.count {
                let sentence = allSentences[i]
                let wordCount = wordCounts[i]

                tentativeSentences.append((sentence, wordCount))
                chunkWordCount += wordCount

                if wordCount >= minWordsForSignificantSentence {
                    significantSentenceCount += 1
                }

                if chunkWordCount >= targetWordCount {
                    break
                }
            }

            let finalSentences: [String]
            if significantSentenceCount > maxSentencesPerChunk {
                // Trim to maxSentencesPerChunk significant sentences
                finalSentences = trimToMaxSignificantSentences(tentativeSentences)
            } else {
                finalSentences = tentativeSentences.map(\.sentence)
            }

            if !finalSentences.isEmpty {
                chunks.append(finalSentences.joined(separator: " "))
                processedIndex += finalSentences.count
            } else {
                // Skip any remaining sentences if we can't form a chunk
                processedIndex += max(tentativeSentences.count, 1)
            }
        }

        return chunks.joined(separator: "\n\n")
    }

    // MARK: - Private Helpers

    /// Counts words in text using NaturalLanguage tokenizer.
    ///
    /// - Parameters:
    ///   - text: Text to count words in.
    ///   - tokenizer: Pre-configured NLTokenizer to reuse (for performance).
    /// - Returns: Number of words in the text.
    private static func countWords(in text: String, using tokenizer: NLTokenizer) -> Int {
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

    /// Trims a list of sentences to include at most `maxSentencesPerChunk` significant sentences.
    ///
    /// Short sentences (fewer than `minWordsForSignificantSentence` words) are included but don't
    /// count toward the limit. This allows natural conversation fragments like "Yes." or "I see."
    /// to remain with their context.
    ///
    /// - Parameter sentences: Array of tuples containing sentence text and pre-computed word count.
    /// - Returns: Array of sentence strings, trimmed at the Nth significant sentence.
    private static func trimToMaxSignificantSentences(_ sentences: [(sentence: String, wordCount: Int)]) -> [String] {
        var result = [String]()
        var significantCount = 0

        for (sentence, wordCount) in sentences {
            result.append(sentence)
            if wordCount >= minWordsForSignificantSentence {
                significantCount += 1
                if significantCount >= maxSentencesPerChunk {
                    break
                }
            }
        }
        return result
    }
}
