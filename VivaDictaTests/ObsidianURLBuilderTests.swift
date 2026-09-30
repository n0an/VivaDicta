//
//  ObsidianURLBuilderTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.30
//

import Foundation
import Testing
@testable import VivaDicta

struct ObsidianURLBuilderTests {

    private let date = NoteTemplateTests.fixedDate
    private let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    // MARK: - Standard URL

    @Test func standard_buildsNewNoteURLWithClipboardAppend() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "Hello",
                                                           template: "VivaDicta {date}",
                                                           modeName: "Default",
                                                           presetName: nil,
                                                           date: date))
        #expect(output.url.absoluteString == "obsidian://new?file=VivaDicta%202026-09-30&clipboard&append=true")
        #expect(output.clipboardText == "Hello\n")
    }

    @Test func standard_emptyNoteNameReturnsNil() {
        let output = ObsidianURLBuilder.build(text: "Hello",
                                              template: "",
                                              modeName: "Default",
                                              presetName: nil,
                                              date: date)
        #expect(output == nil)
    }

    @Test func standard_blankCustomTemplateFallsBackToStandard() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "Hello",
                                                           template: "{date}",
                                                           customURLTemplate: "   \n",
                                                           modeName: "Default",
                                                           presetName: nil,
                                                           date: date))
        #expect(output.url.host() == "new")
    }

    // MARK: - Custom URL

    @Test func custom_obsidianOpenWithPrepend() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "Купить хлеб & молоко",
                                                           template: "{date}",
                                                           customURLTemplate: "obsidian://open?file=Daily%2F{date}&prepend={text}",
                                                           modeName: "Default",
                                                           presetName: nil,
                                                           date: date))
        let components = try #require(URLComponents(url: output.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "obsidian")
        #expect(components.host == "open")
        #expect(components.queryItems?.first { $0.name == "file" }?.value == "Daily/2026-09-30")
        #expect(components.queryItems?.first { $0.name == "prepend" }?.value == "Купить хлеб & молоко")
        #expect(output.clipboardText == "Купить хлеб & молоко\n")
    }

    @Test func custom_advancedURIStyleTemplate() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "Note text",
            template: "{date}",
            customURLTemplate: "obsidian://advanced-uri?filepath=daily/{date}&data={text}&mode=prepend",
            modeName: "Default",
            presetName: nil,
            date: date))
        let components = try #require(URLComponents(url: output.url, resolvingAgainstBaseURL: false))
        #expect(components.host == "advanced-uri")
        #expect(components.queryItems?.first { $0.name == "filepath" }?.value == "daily/2026-09-30")
        #expect(components.queryItems?.first { $0.name == "data" }?.value == "Note text")
        #expect(components.queryItems?.first { $0.name == "mode" }?.value == "prepend")
    }

    @Test func custom_textAndOriginalAreDistinct() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "Enhanced",
                                                           originalText: "raw",
                                                           template: "{date}",
                                                           customURLTemplate: "obsidian://new?file={id}&content={original}%0A{text}",
                                                           modeName: "Default",
                                                           presetName: "Summary",
                                                           transcriptionID: id,
                                                           date: date))
        let components = try #require(URLComponents(url: output.url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "file" }?.value == id.uuidString)
        #expect(components.queryItems?.first { $0.name == "content" }?.value == "raw\nEnhanced")
    }

    @Test func custom_originalDefaultsToText() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "Same",
                                                           template: "{date}",
                                                           customURLTemplate: "obsidian://new?content={original}",
                                                           modeName: "Default",
                                                           presetName: nil,
                                                           date: date))
        #expect(output.url.absoluteString == "obsidian://new?content=Same")
    }

    @Test func custom_textCannotInjectQueryParameters() throws {
        let output = try #require(ObsidianURLBuilder.build(text: "a&vault=Other",
                                                           template: "{date}",
                                                           customURLTemplate: "obsidian://new?content={text}",
                                                           modeName: "Default",
                                                           presetName: nil,
                                                           date: date))
        let components = try #require(URLComponents(url: output.url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.count == 1)
        #expect(components.queryItems?.first?.value == "a&vault=Other")
    }

    @Test func custom_withoutSchemeReturnsNil() {
        let output = ObsidianURLBuilder.build(text: "Hello",
                                              template: "{date}",
                                              customURLTemplate: "just some text {text}",
                                              modeName: "Default",
                                              presetName: nil,
                                              date: date)
        #expect(output == nil)
    }
}
