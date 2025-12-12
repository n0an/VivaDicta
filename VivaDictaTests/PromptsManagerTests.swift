//
//  PromptsManagerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.12.12
//

import Foundation
import Testing
@testable import VivaDicta

struct PromptsManagerTests {

    private let testKey = "testUserPrompts"

    private func makeManager() -> PromptsManager {
        let defaults = UserDefaults(suiteName: "PromptsManagerTests")!
        defaults.removeObject(forKey: testKey)
        return PromptsManager(userDefaults: defaults, storageKey: testKey)
    }

    // MARK: - Duplicate Name Detection Tests

    @Test func testIsPromptNameDuplicate_noDuplicates_returnsFalse() {
        let manager = makeManager()
        manager.addPrompt(UserPrompt(title: "Email", promptInstructions: "Format as email"))

        #expect(manager.isPromptNameDuplicate("Chat") == false)
    }

    @Test func testIsPromptNameDuplicate_exactMatch_returnsTrue() {
        let manager = makeManager()
        manager.addPrompt(UserPrompt(title: "Email", promptInstructions: "Format as email"))

        #expect(manager.isPromptNameDuplicate("Email") == true)
    }

    @Test func testIsPromptNameDuplicate_caseInsensitive_returnsTrue() {
        let manager = makeManager()
        manager.addPrompt(UserPrompt(title: "Email", promptInstructions: "Format as email"))

        #expect(manager.isPromptNameDuplicate("email") == true)
        #expect(manager.isPromptNameDuplicate("EMAIL") == true)
        #expect(manager.isPromptNameDuplicate("eMaIl") == true)
    }

    @Test func testIsPromptNameDuplicate_withWhitespace_trimmed() {
        let manager = makeManager()
        manager.addPrompt(UserPrompt(title: "Email", promptInstructions: "Format as email"))

        #expect(manager.isPromptNameDuplicate("  Email  ") == true)
        #expect(manager.isPromptNameDuplicate("\tEmail\n") == true)
    }

    @Test func testIsPromptNameDuplicate_excludingId_allowsSameName() {
        let manager = makeManager()
        let prompt = UserPrompt(title: "Email", promptInstructions: "Format as email")
        manager.addPrompt(prompt)

        // Same name but excluding the prompt's own ID should return false
        #expect(manager.isPromptNameDuplicate("Email", excludingId: prompt.id) == false)
    }

    @Test func testIsPromptNameDuplicate_excludingId_detectsOtherDuplicates() {
        let manager = makeManager()
        let prompt1 = UserPrompt(title: "Email", promptInstructions: "Format as email")
        let prompt2 = UserPrompt(title: "Chat", promptInstructions: "Format as chat")
        manager.addPrompt(prompt1)
        manager.addPrompt(prompt2)

        // Trying to rename prompt2 to "Email" should detect duplicate
        #expect(manager.isPromptNameDuplicate("Email", excludingId: prompt2.id) == true)
    }

    @Test func testIsPromptNameDuplicate_emptyList_returnsFalse() {
        let manager = makeManager()

        #expect(manager.isPromptNameDuplicate("Email") == false)
    }

    // MARK: - Add Prompt Tests

    @Test func testAddPrompt_success() {
        let manager = makeManager()
        let prompt = UserPrompt(title: "Test", promptInstructions: "Test instructions")

        manager.addPrompt(prompt)

        #expect(manager.userPrompts.count == 1)
        #expect(manager.userPrompts.first?.title == "Test")
    }

    @Test func testAddPrompt_multiplePrompts() {
        let manager = makeManager()

        manager.addPrompt(UserPrompt(title: "Email", promptInstructions: "Email format"))
        manager.addPrompt(UserPrompt(title: "Chat", promptInstructions: "Chat format"))
        manager.addPrompt(UserPrompt(title: "Notes", promptInstructions: "Notes format"))

        #expect(manager.userPrompts.count == 3)
    }

    // MARK: - Update Prompt Tests

    @Test func testUpdatePrompt_success() {
        let manager = makeManager()
        let prompt = UserPrompt(title: "Original", promptInstructions: "Original instructions")
        manager.addPrompt(prompt)

        let updated = UserPrompt(id: prompt.id, title: "Updated", promptInstructions: "Updated instructions", createdAt: prompt.createdAt)
        manager.updatePrompt(updated)

        #expect(manager.userPrompts.count == 1)
        #expect(manager.userPrompts.first?.title == "Updated")
    }

    // MARK: - Delete Prompt Tests

    @Test func testDeletePrompt_success() {
        let manager = makeManager()
        let prompt = UserPrompt(title: "ToDelete", promptInstructions: "Delete me")
        manager.addPrompt(prompt)

        manager.deletePrompt(prompt)

        #expect(manager.userPrompts.isEmpty)
    }
}
