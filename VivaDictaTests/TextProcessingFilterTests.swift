//
//  TextProcessingFilterTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import TextProcessing
import Testing
@testable import VivaDicta
import AICore

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

        #expect(result.contains("[background noise]") == false)
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    @Test func filter_removesParenthesizedContent() {
        let input = "Hello (inaudible) world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result.contains("(inaudible)") == false)
    }

    @Test func filter_removesBracedContent() {
        let input = "Hello {music} world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result.contains("{music}") == false)
    }

    // MARK: - filter Tests — Filler Words

    @Test func filter_removesFillerWords() {
        let input = "So uh I think um we should eh go"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result.contains(" uh ") == false)
        #expect(result.contains(" um ") == false)
        #expect(result.contains(" eh ") == false)
        #expect(result.contains("I think"))
        #expect(result.contains("we should"))
    }

    @Test func filter_removesFillerWordsWithPunctuation() {
        let input = "Well, uh, I think so"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result.contains("uh,") == false)
    }

    // MARK: - filter Tests — Tag Removal

    @Test func filter_removesXMLTagBlocks() {
        let input = "Hello <note>this is a note</note> world"
        let result = TranscriptionOutputFilter.filter(input)

        #expect(result.contains("<note>") == false)
        #expect(result.contains("this is a note") == false)
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

    // MARK: - filter Tests — Multilingual Fillers

    @Test func filter_universalFillers_strippedRegardlessOfLanguage() {
        // "uh", "um", "hmm" should be removed for any language.
        let inputRu = "Это um важное hmm сообщение для теста."
        let result = TranscriptionOutputFilter.filter(inputRu, language: "ru")

        #expect(result.contains("um") == false)
        #expect(result.contains("hmm") == false)
    }

    @Test(arguments: [
        (
            lang: "ru",
            input: "Я думаю ээ что нам ыыы нужно идти.",
            removed: ["ээ", "ыыы"],
            kept: ["Я думаю", "нужно идти"]
        ),
        (
            lang: "ru",
            input: "Я э-э думаю что э-э-э нам нужно идти.",
            removed: ["э-э"],
            kept: ["Я", "думаю", "нужно идти"]
        ),
        (
            lang: "de",
            input: "Ich denke äh dass wir ähm gehen sollten.",
            removed: ["äh", "ähm"],
            kept: ["Ich denke", "gehen sollten"]
        ),
        (
            lang: "fr",
            input: "Je pense euh qu'on devrait heu y aller.",
            removed: ["euh", "heu"],
            kept: ["Je pense", "y aller"]
        ),
        (
            lang: "es",
            input: "Yo creo ehm que deberíamos eee ir.",
            removed: ["ehm", "eee"],
            kept: ["Yo creo", "deberíamos"]
        ),
    ])
    func filter_languageFillers_removedWhenLanguageMatches(
        lang: String,
        input: String,
        removed: [String],
        kept: [String]
    ) {
        let result = TranscriptionOutputFilter.filter(input, language: lang)

        for token in removed {
            #expect(result.contains(token) == false, "[\(lang)] expected \"\(token)\" to be removed; got: \(result)")
        }
        for token in kept {
            #expect(result.contains(token), "[\(lang)] expected \"\(token)\" to be kept; got: \(result)")
        }
    }

    @Test func filter_germanFillers_notRemovedWhenLanguageIsRussian() {
        // German "äh" should NOT be stripped when language is Russian
        // (it's not in the Russian filler list).
        let input = "äh test"
        let result = TranscriptionOutputFilter.filter(input, language: "ru")

        #expect(result.contains("äh"))
    }

    @Test func filter_englishFallback_whenLanguageUnknown() {
        // "auto" with text too short for confident detection → English fallback,
        // so English-specific fillers (eh) should still be stripped.
        let input = "Well, eh, ok."
        let result = TranscriptionOutputFilter.filter(input, language: "auto")

        #expect(result.contains("eh") == false)
    }

    @Test func filter_explicitLanguageWithRegionSuffix_resolvesToBase() {
        // "en-US" should be treated as "en".
        let input = "I think eh we should go."
        let result = TranscriptionOutputFilter.filter(input, language: "en-US")

        #expect(result.contains(" eh ") == false)
    }

    // MARK: - stripTrailingPeriod Tests

    @Test func stripTrailingPeriod_singleSentence_removesPeriod() {
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Okay.") == "Okay")
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Sure.") == "Sure")
    }

    @Test func stripTrailingPeriod_multipleSentences_removesOnlyTrailing() {
        #expect(
            TranscriptionOutputFilter.stripTrailingPeriods("Sure. I'll be there.")
            == "Sure. I'll be there"
        )
    }

    @Test func stripTrailingPeriod_ellipsis_strippedToo() {
        // Per the user spec (Peter Szemraj): rstrip('.') eats trailing ellipses too.
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Wait...") == "Wait")
    }

    @Test func stripTrailingPeriod_questionMark_unchanged() {
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("What?") == "What?")
    }

    @Test func stripTrailingPeriod_exclamation_unchanged() {
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Yes!") == "Yes!")
    }

    @Test func stripTrailingPeriod_noTrailingPeriod_unchanged() {
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Okay") == "Okay")
    }

    @Test func stripTrailingPeriod_emptyString_unchanged() {
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("") == "")
    }

    @Test func stripTrailingPeriod_trailingWhitespaceAfterPeriod_stillStrips() {
        // "Okay.   " - trim runs first inside the helper, so the period is still recognized.
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("Okay.   ") == "Okay")
    }

    @Test func stripTrailingPeriod_internalPeriods_untouched() {
        // Periods that aren't at the very end (acronyms, mid-sentence) stay put.
        #expect(
            TranscriptionOutputFilter.stripTrailingPeriods("J.R.R. Tolkien")
            == "J.R.R. Tolkien"
        )
    }

    @Test func stripTrailingPeriod_leadingWhitespace_preserved() {
        // Function only touches the tail - leading whitespace passes through
        // even though the rest of the pipeline normally trims it.
        #expect(TranscriptionOutputFilter.stripTrailingPeriods("  Okay.") == "  Okay")
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

// MARK: - Output Language Resolution (inline translation)

// `TranscriptionManager.outputLanguage` inherits MainActor isolation from its
// enclosing `@MainActor` type, so these tests run on the main actor to call it
// synchronously.
@MainActor
struct TranscriptionOutputLanguageTests {

    @Test func outputLanguage_noTranslation_usesTranscriptionLanguage() {
        let result = TranscriptionManager.outputLanguage(
            transcriptionLanguage: "es",
            translationTargetLanguage: nil
        )

        #expect(result == "es")
    }

    @Test func outputLanguage_emptyTranslationTarget_usesTranscriptionLanguage() {
        let result = TranscriptionManager.outputLanguage(
            transcriptionLanguage: "es",
            translationTargetLanguage: ""
        )

        #expect(result == "es")
    }

    @Test func outputLanguage_translationActive_usesTargetLanguage() {
        // Spanish audio translated to Russian → output is Russian, so the
        // filler set must be chosen from the target language.
        let result = TranscriptionManager.outputLanguage(
            transcriptionLanguage: "es",
            translationTargetLanguage: "ru"
        )

        #expect(result == "ru")
    }

    @Test func outputLanguage_translationTargetWithoutSource_usesTargetLanguage() {
        // Target set with no explicit source ("auto" source) → still resolves
        // to the target, since that's the language of the output text.
        let result = TranscriptionManager.outputLanguage(
            transcriptionLanguage: nil,
            translationTargetLanguage: "ru"
        )

        #expect(result == "ru")
    }

    @Test func filter_spanishToRussian_stripsRussianFillers() {
        // Regression: Soniox Spanish → Russian produced Russian text full of
        // "э-э" fillers because the filter was given the source language ("es").
        // Resolving the output language to the translation target fixes it.
        let translatedOutput = "Э-э, привет, э-э, сейчас я говорю по-испански."
        let language = TranscriptionManager.outputLanguage(
            transcriptionLanguage: "es",
            translationTargetLanguage: "ru"
        )

        let result = TranscriptionOutputFilter.filter(translatedOutput, language: language)

        #expect(result.contains("э-э") == false, "expected Russian fillers stripped; got: \(result)")
        #expect(result.contains("привет"))
        #expect(result.contains("по-испански"))
    }
}
