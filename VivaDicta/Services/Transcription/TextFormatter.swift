//
//  TextFormatter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.27
//

import Foundation
import NaturalLanguage

struct TextFormatter {
    static func format(_ text: String) -> String {
        let TARGET_WORD_COUNT = 50
        let MAX_SENTENCES_PER_CHUNK = 4
        let MIN_WORDS_FOR_SIGNIFICANT_SENTENCE = 4

        var finalFormattedText = ""

        let detectedLanguage = NLLanguageRecognizer.dominantLanguage(for: text)
        let tokenizerLanguage = detectedLanguage ?? .english

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        sentenceTokenizer.setLanguage(tokenizerLanguage)

        var allSentencesFromInput = [String]()
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { sentenceRange, _ in
            let rawSentence = String(text[sentenceRange])
            allSentencesFromInput.append(rawSentence.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }

        guard !allSentencesFromInput.isEmpty else {
            return ""
        }

        var processedSentenceGlobalIndex = 0

        while processedSentenceGlobalIndex < allSentencesFromInput.count {
            var currentChunkTentativeSentences = [String]()
            var currentChunkWordCount = 0
            var currentChunkSignificantSentenceCount = 0

            for i in processedSentenceGlobalIndex..<allSentencesFromInput.count {
                let sentence = allSentencesFromInput[i]

                let wordTokenizer = NLTokenizer(unit: .word)
                wordTokenizer.string = sentence
                wordTokenizer.setLanguage(tokenizerLanguage)
                var wordsInSentence = 0
                wordTokenizer.enumerateTokens(in: sentence.startIndex..<sentence.endIndex) { _, _ in
                    wordsInSentence += 1
                    return true
                }

                currentChunkTentativeSentences.append(sentence)
                currentChunkWordCount += wordsInSentence

                if wordsInSentence >= MIN_WORDS_FOR_SIGNIFICANT_SENTENCE {
                    currentChunkSignificantSentenceCount += 1
                }

                if currentChunkWordCount >= TARGET_WORD_COUNT {
                    break
                }
            }

            var sentencesForThisFinalChunk = [String]()
            if currentChunkSignificantSentenceCount > MAX_SENTENCES_PER_CHUNK {
                var significantSentencesCountedInTrim = 0
                for sentenceInTentativeChunk in currentChunkTentativeSentences {
                    sentencesForThisFinalChunk.append(sentenceInTentativeChunk)

                    let wordTokenizerForTrimCheck = NLTokenizer(unit: .word)
                    wordTokenizerForTrimCheck.string = sentenceInTentativeChunk
                    wordTokenizerForTrimCheck.setLanguage(tokenizerLanguage)
                    var wordsInCurrentSentenceForTrim = 0
                    wordTokenizerForTrimCheck.enumerateTokens(in: sentenceInTentativeChunk.startIndex..<sentenceInTentativeChunk.endIndex) { _, _ in
                        wordsInCurrentSentenceForTrim += 1
                        return true
                    }

                    if wordsInCurrentSentenceForTrim >= MIN_WORDS_FOR_SIGNIFICANT_SENTENCE {
                        significantSentencesCountedInTrim += 1
                        if significantSentencesCountedInTrim >= MAX_SENTENCES_PER_CHUNK {
                            break
                        }
                    }
                }
            } else {
                sentencesForThisFinalChunk = currentChunkTentativeSentences
            }

            if !sentencesForThisFinalChunk.isEmpty {
                let segmentStringToAppend = sentencesForThisFinalChunk.joined(separator: " ")

                if !finalFormattedText.isEmpty {
                    finalFormattedText += "\n\n"
                }
                finalFormattedText += segmentStringToAppend

                processedSentenceGlobalIndex += sentencesForThisFinalChunk.count
            } else {
                if processedSentenceGlobalIndex >= allSentencesFromInput.count && currentChunkTentativeSentences.isEmpty {
                    break
                } else if sentencesForThisFinalChunk.isEmpty && !currentChunkTentativeSentences.isEmpty {
                    processedSentenceGlobalIndex += currentChunkTentativeSentences.count
                } else if sentencesForThisFinalChunk.isEmpty && currentChunkTentativeSentences.isEmpty && processedSentenceGlobalIndex < allSentencesFromInput.count {
                    processedSentenceGlobalIndex = allSentencesFromInput.count
                    break
                } else if sentencesForThisFinalChunk.isEmpty {
                    break
                }
            }
        }

        return finalFormattedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
