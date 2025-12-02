//
//  TextFormatter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.27
//

import Foundation
import NaturalLanguage

struct TextFormatter {
    private static let targetWordCount = 50
    private static let maxSentencesPerChunk = 4
    private static let minWordsForSignificantSentence = 4

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

    private static func countWords(in text: String, using tokenizer: NLTokenizer) -> Int {
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

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
