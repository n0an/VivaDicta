//
//  ReplacementsServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.10
//

import Foundation
import Testing
@testable import VivaDicta

struct ReplacementsServiceTests {

    private let testKey = "testTextReplacements"

    private func makeService() -> ReplacementsService {
        let defaults = UserDefaults(suiteName: "ReplacementsServiceTests")!
        defaults.removeObject(forKey: testKey)
        return ReplacementsService(userDefaults: defaults, storageKey: testKey)
    }

    // MARK: - Add Replacement Tests

    @Test func testAddReplacement_success() {
        let service = makeService()

        service.addReplacement(original: "hello", replacement: "world")

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "hello")
        #expect(service.replacements.first?.replacement == "world")
    }

    @Test func testAddReplacement_trimWhitespace() {
        let service = makeService()

        service.addReplacement(original: "  hello  ", replacement: "  world  ")

        #expect(service.replacements.first?.original == "hello")
        #expect(service.replacements.first?.replacement == "world")
    }

    @Test func testAddReplacement_emptyOriginal_ignored() {
        let service = makeService()

        service.addReplacement(original: "", replacement: "world")
        service.addReplacement(original: "   ", replacement: "world")

        #expect(service.replacements.isEmpty)
    }

    @Test func testAddReplacement_emptyReplacement_ignored() {
        let service = makeService()

        service.addReplacement(original: "hello", replacement: "")
        service.addReplacement(original: "hello", replacement: "   ")

        #expect(service.replacements.isEmpty)
    }

    @Test func testAddReplacement_duplicate_caseInsensitive() {
        let service = makeService()

        service.addReplacement(original: "Hello", replacement: "World")
        service.addReplacement(original: "hello", replacement: "Universe")
        service.addReplacement(original: "HELLO", replacement: "Galaxy")

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "Hello")
        #expect(service.replacements.first?.replacement == "World")
    }

    @Test func testAddReplacement_insertsAtBeginning() {
        let service = makeService()

        service.addReplacement(original: "first", replacement: "1st")
        service.addReplacement(original: "second", replacement: "2nd")

        #expect(service.replacements.first?.original == "second")
        #expect(service.replacements.last?.original == "first")
    }

    @Test func testAddReplacement_truncatesLongOriginal() {
        let service = makeService()
        let longText = String(repeating: "a", count: 150)

        service.addReplacement(original: longText, replacement: "short")

        #expect(service.replacements.first?.original.count == ReplacementsService.maxTextLength)
    }

    @Test func testAddReplacement_truncatesLongReplacement() {
        let service = makeService()
        let longText = String(repeating: "b", count: 150)

        service.addReplacement(original: "short", replacement: longText)

        #expect(service.replacements.first?.replacement.count == ReplacementsService.maxTextLength)
    }

    // MARK: - Update Replacement Tests

    @Test func testUpdateReplacement_success() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")
        let original = service.replacements.first!

        service.updateReplacement(original, original: "hi", replacement: "earth")

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "hi")
        #expect(service.replacements.first?.replacement == "earth")
    }

    @Test func testUpdateReplacement_preservesPosition() {
        let service = makeService()
        service.addReplacement(original: "first", replacement: "1st")
        service.addReplacement(original: "second", replacement: "2nd")
        service.addReplacement(original: "third", replacement: "3rd")

        let secondReplacement = service.replacements[1]
        service.updateReplacement(secondReplacement, original: "updated", replacement: "new")

        #expect(service.replacements[1].original == "updated")
        #expect(service.replacements[1].replacement == "new")
    }

    @Test func testUpdateReplacement_duplicateOriginal_rejected() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")
        service.addReplacement(original: "hi", replacement: "earth")

        let hiReplacement = service.replacements.first { $0.original == "hi" }!
        service.updateReplacement(hiReplacement, original: "Hello", replacement: "universe")

        // Should not update because "Hello" already exists (case-insensitive)
        #expect(service.replacements.contains { $0.original == "hi" })
        #expect(service.replacements.contains { $0.original == "hello" })
    }

    @Test func testUpdateReplacement_sameOriginalDifferentCase_allowed() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")

        let helloReplacement = service.replacements.first!
        service.updateReplacement(helloReplacement, original: "Hello", replacement: "World")

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "Hello")
    }

    @Test func testUpdateReplacement_emptyValues_ignored() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")

        let original = service.replacements.first!
        service.updateReplacement(original, original: "", replacement: "new")
        service.updateReplacement(original, original: "new", replacement: "")

        #expect(service.replacements.first?.original == "hello")
        #expect(service.replacements.first?.replacement == "world")
    }

    @Test func testUpdateReplacement_truncatesLongText() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")
        let longText = String(repeating: "x", count: 150)

        let original = service.replacements.first!
        service.updateReplacement(original, original: longText, replacement: longText)

        #expect(service.replacements.first?.original.count == ReplacementsService.maxTextLength)
        #expect(service.replacements.first?.replacement.count == ReplacementsService.maxTextLength)
    }

    // MARK: - Delete Replacement Tests

    @Test func testDeleteReplacement() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")
        service.addReplacement(original: "hi", replacement: "earth")

        let helloReplacement = service.replacements.first { $0.original == "hello" }!
        service.deleteReplacement(helloReplacement)

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "hi")
    }

    @Test func testDeleteReplacement_nonExistent_noEffect() {
        let service = makeService()
        service.addReplacement(original: "hello", replacement: "world")

        let fakeReplacement = Replacement(original: "fake", replacement: "fake")
        service.deleteReplacement(fakeReplacement)

        #expect(service.replacements.count == 1)
    }

    @Test func testDeleteReplacementsAtOffsets() {
        let service = makeService()
        service.addReplacement(original: "first", replacement: "1st")
        service.addReplacement(original: "second", replacement: "2nd")
        service.addReplacement(original: "third", replacement: "3rd")

        service.deleteReplacements(at: IndexSet([0, 2]))

        #expect(service.replacements.count == 1)
        #expect(service.replacements.first?.original == "second")
    }

    // MARK: - Persistence Tests

    @Test func testPersistence() {
        let defaults = UserDefaults(suiteName: "ReplacementsServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = ReplacementsService(userDefaults: defaults, storageKey: testKey)
        service1.addReplacement(original: "persisted", replacement: "data")

        let service2 = ReplacementsService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.replacements.count == 1)
        #expect(service2.replacements.first?.original == "persisted")

        defaults.removeObject(forKey: testKey)
    }

    @Test func testPersistence_afterUpdate() {
        let defaults = UserDefaults(suiteName: "ReplacementsServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = ReplacementsService(userDefaults: defaults, storageKey: testKey)
        service1.addReplacement(original: "original", replacement: "value")
        let replacement = service1.replacements.first!
        service1.updateReplacement(replacement, original: "updated", replacement: "newValue")

        let service2 = ReplacementsService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.replacements.first?.original == "updated")
        #expect(service2.replacements.first?.replacement == "newValue")

        defaults.removeObject(forKey: testKey)
    }

    @Test func testPersistence_afterDelete() {
        let defaults = UserDefaults(suiteName: "ReplacementsServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = ReplacementsService(userDefaults: defaults, storageKey: testKey)
        service1.addReplacement(original: "toDelete", replacement: "gone")
        service1.addReplacement(original: "toKeep", replacement: "stay")
        let toDelete = service1.replacements.first { $0.original == "toDelete" }!
        service1.deleteReplacement(toDelete)

        let service2 = ReplacementsService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.replacements.count == 1)
        #expect(service2.replacements.first?.original == "toKeep")

        defaults.removeObject(forKey: testKey)
    }

    // MARK: - Word Boundary Detection Tests

    @Test func testUsesWordBoundaries_english() {
        #expect(ReplacementsService.usesWordBoundaries(for: "hello") == true)
        #expect(ReplacementsService.usesWordBoundaries(for: "Hello World") == true)
    }

    @Test func testUsesWordBoundaries_japanese() {
        #expect(ReplacementsService.usesWordBoundaries(for: "こんにちは") == false) // Hiragana
        #expect(ReplacementsService.usesWordBoundaries(for: "カタカナ") == false) // Katakana
        #expect(ReplacementsService.usesWordBoundaries(for: "漢字") == false) // Kanji
    }

    @Test func testUsesWordBoundaries_korean() {
        #expect(ReplacementsService.usesWordBoundaries(for: "안녕하세요") == false) // Hangul
    }

    @Test func testUsesWordBoundaries_thai() {
        #expect(ReplacementsService.usesWordBoundaries(for: "สวัสดี") == false) // Thai
    }

    @Test func testUsesWordBoundaries_mixed() {
        // Mixed text with CJK should return false
        #expect(ReplacementsService.usesWordBoundaries(for: "hello世界") == false)
    }

    // MARK: - Apply Replacements Tests

    @Test func testApplyReplacements_basic() {
        let replacements = [
            Replacement(original: "hello", replacement: "hi")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "hello world")

        #expect(result == "hi world")
    }

    @Test func testApplyReplacements_caseInsensitive() {
        let replacements = [
            Replacement(original: "hello", replacement: "hi")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "HELLO World")

        #expect(result == "hi World")
    }

    @Test func testApplyReplacements_wordBoundaries() {
        let replacements = [
            Replacement(original: "cat", replacement: "dog")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "The cat sat. Category is different.")

        #expect(result == "The dog sat. Category is different.")
    }

    @Test func testApplyReplacements_multipleOccurrences() {
        let replacements = [
            Replacement(original: "test", replacement: "exam")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "test one test two test three")

        #expect(result == "exam one exam two exam three")
    }

    @Test func testApplyReplacements_multipleReplacements() {
        let replacements = [
            Replacement(original: "hello", replacement: "hi"),
            Replacement(original: "world", replacement: "earth")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "hello world")

        #expect(result == "hi earth")
    }

    @Test func testApplyReplacements_specialCharacters() {
        let replacements = [
            Replacement(original: "c++", replacement: "cpp")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "I code in c++ daily")

        #expect(result == "I code in cpp daily")
    }

    @Test func testApplyReplacements_cjkWithoutBoundaries() {
        let replacements = [
            Replacement(original: "世界", replacement: "地球")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "こんにちは世界")

        #expect(result == "こんにちは地球")
    }

    @Test func testApplyReplacements_emptyReplacements() {
        let result = ReplacementsService.applyReplacements([], to: "hello world")

        #expect(result == "hello world")
    }

    @Test func testApplyReplacements_noMatch() {
        let replacements = [
            Replacement(original: "xyz", replacement: "abc")
        ]

        let result = ReplacementsService.applyReplacements(replacements, to: "hello world")

        #expect(result == "hello world")
    }
}
