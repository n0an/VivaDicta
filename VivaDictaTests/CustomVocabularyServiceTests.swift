//
//  CustomVocabularyServiceTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.10
//

import Foundation
import Testing
@testable import VivaDicta

struct CustomVocabularyServiceTests {

    private let testKey = "testCustomVocabularyWords"

    private func makeService() -> CustomVocabularyService {
        let defaults = UserDefaults(suiteName: "CustomVocabularyServiceTests")!
        defaults.removeObject(forKey: testKey)
        return CustomVocabularyService(userDefaults: defaults, storageKey: testKey)
    }

    // MARK: - Add Word Tests

    @Test func testAddWord_success() {
        let service = makeService()

        service.addWord("Hello")

        #expect(service.words.count == 1)
        #expect(service.words.first == "Hello")
    }

    @Test func testAddWord_trimWhitespace() {
        let service = makeService()

        service.addWord("  Hello  ")

        #expect(service.words.first == "Hello")
    }

    @Test func testAddWord_emptyString_ignored() {
        let service = makeService()

        service.addWord("")
        service.addWord("   ")

        #expect(service.words.isEmpty)
    }

    @Test func testAddWord_duplicate_caseInsensitive() {
        let service = makeService()

        service.addWord("Hello")
        service.addWord("hello")
        service.addWord("HELLO")

        #expect(service.words.count == 1)
        #expect(service.words.first == "Hello")
    }

    @Test func testAddWord_insertsAtBeginning() {
        let service = makeService()

        service.addWord("First")
        service.addWord("Second")

        #expect(service.words.first == "Second")
        #expect(service.words.last == "First")
    }

    @Test func testAddWord_truncatesLongWord() {
        let service = makeService()
        let longWord = String(repeating: "a", count: 100)

        service.addWord(longWord)

        #expect(service.words.first?.count == CustomVocabularyService.maxWordLength)
    }

    // MARK: - Update Word Tests

    @Test func testUpdateWord_success() {
        let service = makeService()
        service.addWord("Hello")

        service.updateWord("Hello", to: "World")

        #expect(service.words.count == 1)
        #expect(service.words.first == "World")
    }

    @Test func testUpdateWord_preservesPosition() {
        let service = makeService()
        service.addWord("First")
        service.addWord("Second")
        service.addWord("Third")

        service.updateWord("Second", to: "Updated")

        #expect(service.words == ["Third", "Updated", "First"])
    }

    @Test func testUpdateWord_duplicate() {
        let service = makeService()
        service.addWord("Hello")
        service.addWord("World")

        service.updateWord("Hello", to: "World")

        #expect(service.words.count == 2)
        #expect(service.words.contains("Hello"))
        #expect(service.words.contains("World"))
    }

    @Test func testUpdateWord_duplicateCaseInsensitive() {
        let service = makeService()
        service.addWord("Hello")
        service.addWord("World")

        service.updateWord("Hello", to: "WORLD")

        #expect(service.words.count == 2)
        #expect(service.words.contains("Hello"))
    }

    @Test func testUpdateWord_sameWordDifferentCase_allowed() {
        let service = makeService()
        service.addWord("hello")

        service.updateWord("hello", to: "Hello")

        #expect(service.words.count == 1)
        #expect(service.words.first == "Hello")
    }

    @Test func testUpdateWord_emptyString_ignored() {
        let service = makeService()
        service.addWord("Hello")

        service.updateWord("Hello", to: "")
        service.updateWord("Hello", to: "   ")

        #expect(service.words.first == "Hello")
    }

    @Test func testUpdateWord_truncatesLongWord() {
        let service = makeService()
        service.addWord("Hello")
        let longWord = String(repeating: "a", count: 100)

        service.updateWord("Hello", to: longWord)

        #expect(service.words.first?.count == CustomVocabularyService.maxWordLength)
    }

    // MARK: - Delete Word Tests

    @Test func testDeleteWord() {
        let service = makeService()
        service.addWord("Hello")
        service.addWord("World")

        service.deleteWord("Hello")

        #expect(service.words.count == 1)
        #expect(service.words.first == "World")
    }

    @Test func testDeleteWord_nonExistent_noEffect() {
        let service = makeService()
        service.addWord("Hello")

        service.deleteWord("NonExistent")

        #expect(service.words.count == 1)
    }

    @Test func testDeleteWordsAtOffsets() {
        let service = makeService()
        service.addWord("First")
        service.addWord("Second")
        service.addWord("Third")

        service.deleteWords(at: IndexSet([0, 2]))

        #expect(service.words.count == 1)
        #expect(service.words.first == "Second")
    }

    // MARK: - Persistence Tests

    @Test func testPersistence() {
        let defaults = UserDefaults(suiteName: "CustomVocabularyServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)
        service1.addWord("Persisted")

        let service2 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.words.count == 1)
        #expect(service2.words.first == "Persisted")

        defaults.removeObject(forKey: testKey)
    }

    @Test func testPersistence_afterUpdate() {
        let defaults = UserDefaults(suiteName: "CustomVocabularyServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)
        service1.addWord("Original")
        service1.updateWord("Original", to: "Updated")

        let service2 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.words.first == "Updated")

        defaults.removeObject(forKey: testKey)
    }

    @Test func testPersistence_afterDelete() {
        let defaults = UserDefaults(suiteName: "CustomVocabularyServiceTests")!
        defaults.removeObject(forKey: testKey)

        let service1 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)
        service1.addWord("ToDelete")
        service1.addWord("ToKeep")
        service1.deleteWord("ToDelete")

        let service2 = CustomVocabularyService(userDefaults: defaults, storageKey: testKey)

        #expect(service2.words.count == 1)
        #expect(service2.words.first == "ToKeep")

        defaults.removeObject(forKey: testKey)
    }
}
