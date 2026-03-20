//
//  TextFormatterTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct TextFormatterTests {

    // MARK: - Edge Cases

    @Test func format_emptyString_returnsEmpty() {
        let result = TextFormatter.format("")

        #expect(result == "")
    }

    @Test func format_whitespaceOnly_returnsEmpty() {
        let result = TextFormatter.format("   ")

        #expect(result == "")
    }

    @Test func format_trimsWhitespace() {
        let result = TextFormatter.format("  Hello world.  ")

        #expect(!result.hasPrefix(" "))
        #expect(!result.hasSuffix(" "))
    }

    // MARK: - Single Paragraph (Short Text)

    @Test func format_singleShortSentence_singleParagraph() {
        let result = TextFormatter.format("This is a short sentence.")

        #expect(!result.contains("\n\n"))
        #expect(result.contains("This is a short sentence."))
    }

    @Test func format_multipleShortSentences_groupedTogether() {
        // Short sentences (< 4 words each) don't count as "significant"
        let result = TextFormatter.format("Yes. OK. I see. Thanks.")

        #expect(!result.contains("\n\n"))
    }

    // MARK: - Paragraph Splitting

    @Test func format_longText_splitIntoParagraphs() {
        // Build text with 100+ words — should split at ~50 word boundary
        let sentences = (1...20).map { "This is sentence number \($0) with some extra words." }
        let longText = sentences.joined(separator: " ")

        let result = TextFormatter.format(longText)

        #expect(result.contains("\n\n"))
    }

    @Test func format_fiveSignificantSentences_splitAtFourth() {
        // 5 significant sentences (4+ words each) — should split after the 4th
        let sentences = [
            "The first significant sentence here.",
            "The second significant sentence here.",
            "The third significant sentence here.",
            "The fourth significant sentence here.",
            "The fifth significant sentence here."
        ]
        let text = sentences.joined(separator: " ")

        let result = TextFormatter.format(text)

        let paragraphs = result.components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 2)
        // First paragraph should contain 4 significant sentences
        #expect(paragraphs[0].contains("fourth"))
        #expect(!paragraphs[0].contains("fifth"))
    }

    @Test func format_mixedShortLongSentences_balanced() {
        // Short sentences don't count as significant, so they shouldn't force premature splits
        let text = "Yes. OK. Sure. The first significant sentence about something. The second significant sentence about something. The third significant sentence about something. The fourth significant sentence here. Right. The fifth significant sentence about another thing."

        let result = TextFormatter.format(text)

        let paragraphs = result.components(separatedBy: "\n\n")
        // Short sentences "Yes. OK. Sure." and "Right." don't count toward the 4-sentence limit
        #expect(paragraphs.count >= 2)
    }

    // MARK: - Language & Word Counting

    @Test func format_numbersCountAsWords() {
        // Numbers should be counted as words by NLTokenizer
        let shortNumberText = "123 456 789."

        let result = TextFormatter.format(shortNumberText)

        // Short enough text → no split
        #expect(!result.contains("\n\n"))
    }

    @Test func format_russianText_handledCorrectly() {
        // NaturalLanguage should detect Russian and tokenize correctly
        let russianText = "Это первое предложение на русском языке. Это второе предложение которое тоже довольно длинное. Третье предложение содержит важную информацию для теста. Четвёртое предложение добавлено сюда для проверки. Пятое предложение является последним в этом тесте."

        let result = TextFormatter.format(russianText)

        let paragraphs = result.components(separatedBy: "\n\n")
        // 5 significant sentences → should split after 4th
        #expect(paragraphs.count >= 2)
    }

    // MARK: - Existing Newlines

    @Test func format_preservesContentAcrossParagraphs() {
        // Even after formatting, all original content should be present
        let text = "First sentence here. Second sentence here. Third sentence about something important."

        let result = TextFormatter.format(text)

        #expect(result.contains("First sentence here."))
        #expect(result.contains("Third sentence about something important."))
    }
}
