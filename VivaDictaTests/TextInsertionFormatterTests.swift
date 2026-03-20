//
//  TextInsertionFormatterTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct TextInsertionFormatterTests {

    // MARK: - Test Helpers

    private func makeContext(
        textBefore: String = "",
        textAfter: String = "",
        charBefore: Character? = nil,
        charAfter: Character? = nil
    ) -> TextInsertionFormatter.InsertionContext {
        TextInsertionFormatter.InsertionContext(
            textBefore: textBefore,
            textAfter: textAfter,
            charBeforeCursor: charBefore ?? textBefore.last,
            charAfterCursor: charAfter ?? textAfter.first
        )
    }

    // MARK: - No Context

    @Test func formatForInsertion_noContext_appendsSpace() {
        let result = TextInsertionFormatter.formatTextForInsertion("hello", context: nil)

        #expect(result == "hello ")
    }

    // MARK: - Smart Spacing: Before

    @Test func shouldAddSpaceBefore_afterLetter_true() {
        let context = makeContext(textBefore: "word")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        #expect(result.hasPrefix(" "))
    }

    @Test func shouldAddSpaceBefore_afterWhitespace_false() {
        let context = makeContext(textBefore: "word ")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        #expect(!result.hasPrefix(" "))
    }

    @Test func shouldAddSpaceBefore_afterPeriod_true() {
        let context = makeContext(textBefore: "Hello.")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        // Should have space before (and capitalize — tested separately)
        #expect(result.contains(" "))
    }

    @Test func shouldAddSpaceBefore_nilChar_false() {
        let context = makeContext(textBefore: "")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        // At start of document — no space before, but space after
        #expect(!result.hasPrefix(" "))
    }

    // MARK: - Smart Spacing: After

    @Test func spacing_beforePunctuation_noSpaceAfter() {
        let context = makeContext(textBefore: "word ", textAfter: ".")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        #expect(!result.hasSuffix(" "))
    }

    @Test func spacing_beforeWhitespace_noSpaceAfter() {
        let context = makeContext(textBefore: "word ", textAfter: " more")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        #expect(!result.hasSuffix(" "))
    }

    @Test func spacing_endOfText_addsSpaceAfter() {
        let context = makeContext(textBefore: "word ", textAfter: "")
        let result = TextInsertionFormatter.formatTextForInsertion("test", context: context)

        #expect(result.hasSuffix(" "))
    }

    // MARK: - Smart Capitalization

    @Test func capitalization_startOfDocument_capitalizes() {
        let context = makeContext(textBefore: "")
        let result = TextInsertionFormatter.formatTextForInsertion("hello", context: context)

        #expect(result.first?.isUppercase == true)
    }

    @Test func capitalization_afterPeriodSpace_capitalizes() {
        let context = makeContext(textBefore: "Hello. ")
        let result = TextInsertionFormatter.formatTextForInsertion("world", context: context)

        #expect(result.contains("World"))
    }

    @Test func capitalization_afterExclamation_capitalizes() {
        let context = makeContext(textBefore: "Wow! ")
        let result = TextInsertionFormatter.formatTextForInsertion("that", context: context)

        #expect(result.contains("That"))
    }

    @Test func capitalization_afterNewline_capitalizes() {
        let context = makeContext(textBefore: "Hello\n")
        let result = TextInsertionFormatter.formatTextForInsertion("world", context: context)

        #expect(result.contains("World"))
    }

    @Test func capitalization_afterLetter_lowercases() {
        let context = makeContext(textBefore: "Hello")
        let result = TextInsertionFormatter.formatTextForInsertion("World", context: context)

        // Should lowercase since we're mid-sentence
        #expect(result.contains("world"))
    }

    @Test func capitalization_acronym_preserved() {
        let context = makeContext(textBefore: "Hello")
        let result = TextInsertionFormatter.formatTextForInsertion("API", context: context)

        // Acronyms (all uppercase) should be preserved
        #expect(result.contains("API"))
    }

    @Test func capitalization_emptyText_unchanged() {
        let context = makeContext(textBefore: "Hello. ")
        let result = TextInsertionFormatter.formatTextForInsertion("", context: context)

        #expect(result.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
