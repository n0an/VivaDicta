//
//  TextProcessingFilterTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct TranscriptionOutputFilterTests {

    // MARK: - hasMeaningfulContent Tests

    @Test func hasMeaningfulContent_emptyString_returnsFalse() {
        #expect(TranscriptionOutputFilter.hasMeaningfulContent("") == false)
    }

    @Test func hasMeaningfulContent_whitespaceOnly_returnsFalse() {
        #expect(TranscriptionOutputFilter.hasMeaningfulContent("   \n\t  ") == false)
    }

    @Test func hasMeaningfulContent_punctuationOnly_returnsFalse() {
        #expect(TranscriptionOutputFilter.hasMeaningfulContent("...!?") == false)
    }

    @Test func hasMeaningfulContent_normalText_returnsTrue() {
        #expect(TranscriptionOutputFilter.hasMeaningfulContent("Hello world") == true)
    }

    @Test func hasMeaningfulContent_numbersOnly_returnsTrue() {
        #expect(TranscriptionOutputFilter.hasMeaningfulContent("12345") == true)
    }

    // MARK: - filter Tests — Hallucination Removal

    @Test func filter_removesBracketedContent() {
        let input = "Hello [background noise] world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains("[background noise]"))
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    @Test func filter_removesParenthesizedContent() {
        let input = "Hello (inaudible) world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains("(inaudible)"))
    }

    @Test func filter_removesBracedContent() {
        let input = "Hello {music} world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains("{music}"))
    }

    // MARK: - filter Tests — Filler Words

    @Test func filter_removesFillerWords() {
        let input = "So uh I think um we should eh go"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains(" uh "))
        #expect(!result.contains(" um "))
        #expect(!result.contains(" eh "))
        #expect(result.contains("I think"))
        #expect(result.contains("we should"))
    }

    @Test func filter_removesFillerWordsWithPunctuation() {
        let input = "Well, uh, I think so"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains("uh,"))
    }

    // MARK: - filter Tests — Tag Removal

    @Test func filter_removesXMLTagBlocks() {
        let input = "Hello <note>this is a note</note> world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(!result.contains("<note>"))
        #expect(!result.contains("this is a note"))
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    // MARK: - filter Tests — Whitespace Cleanup

    @Test func filter_collapsesMultipleSpaces() {
        let input = "Hello    world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result == "Hello world")
    }

    @Test func filter_trimsWhitespace() {
        let input = "  Hello world  "
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result == "Hello world")
    }

    @Test func filter_preservesSpeakerParagraphBreaks() {
        let input = "Speaker A: Hello there.\n\nSpeaker B: Hi."
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result == input)
    }

    // MARK: - filter Tests — Clean Input

    @Test func filter_cleanInput_returnsUnchanged() {
        let input = "This is a clean transcription with no issues."
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result == input)
    }
}

// MARK: - AI Processing Output Filter Tests

struct AIProcessingOutputFilterTests {

    // MARK: - Thinking Tag Removal

    @Test func filter_removesThinkingTags() {
        let input = "<thinking>Let me analyze this...</thinking>This is the clean output."
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "This is the clean output.")
    }

    @Test func filter_removesThinkTags() {
        let input = "<think>Processing...</think>Clean result here."
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "Clean result here.")
    }

    @Test func filter_removesReasoningTags() {
        let input = "<reasoning>Step 1: analyze\nStep 2: process</reasoning>Final answer."
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "Final answer.")
    }

    @Test func filter_removesMultilineThinkingTags() {
        let input = """
        <thinking>
        This is a long
        multi-line thinking block
        </thinking>
        The actual output.
        """
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "The actual output.")
    }

    // MARK: - XML Wrapper Unwrapping

    @Test func filter_unwrapsOuterXMLTags() {
        let input = "<TRANSCRIPTION>Clean text here.</TRANSCRIPTION>"
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "Clean text here.")
    }

    @Test func filter_unwrapsNestedOuterXMLTags() {
        let input = "<result><transcription>Clean text here.</transcription></result>"
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "Clean text here.")
    }

    @Test func filter_doesNotUnwrapPartialXMLTags() {
        let input = "Some text <emphasis>important</emphasis> more text"
        let result = AIEnhancementOutputFilter.filter(input)

        // Should not unwrap because tags don't wrap the entire text
        #expect(result == input)
    }

    // MARK: - Clean Input

    @Test func filter_cleanInput_returnsUnchanged() {
        let input = "This is already clean text with no tags."
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == input)
    }

    // MARK: - Combined Scenarios

    @Test func filter_thinkingPlusWrapper_removedCorrectly() {
        let input = "<thinking>Let me think about this</thinking><output>The final result.</output>"
        let result = AIEnhancementOutputFilter.filter(input)

        #expect(result == "The final result.")
    }
}
