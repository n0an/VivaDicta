//
//  ObsidianURLBuilderTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.05.02
//

import Foundation
import Testing
@testable import VivaDicta

struct ObsidianURLBuilderTests {

    private static let fixedDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 2
        components.hour = 14
        components.minute = 23
        components.second = 5
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    // MARK: - sanitizeFolder

    @Test func sanitizeFolder_nilOrEmpty_returnsNil() {
        #expect(ObsidianURLBuilder.sanitizeFolder(nil) == nil)
        #expect(ObsidianURLBuilder.sanitizeFolder("") == nil)
        #expect(ObsidianURLBuilder.sanitizeFolder("   ") == nil)
    }

    @Test func sanitizeFolder_simpleName_returnsAsIs() {
        #expect(ObsidianURLBuilder.sanitizeFolder("daily") == "daily")
    }

    @Test func sanitizeFolder_nestedPath_returnsAsIs() {
        #expect(ObsidianURLBuilder.sanitizeFolder("Inbox/voice") == "Inbox/voice")
    }

    @Test func sanitizeFolder_leadingSlash_stripped() {
        #expect(ObsidianURLBuilder.sanitizeFolder("/daily") == "daily")
    }

    @Test func sanitizeFolder_trailingSlash_stripped() {
        #expect(ObsidianURLBuilder.sanitizeFolder("daily/") == "daily")
    }

    @Test func sanitizeFolder_bothSlashes_stripped() {
        #expect(ObsidianURLBuilder.sanitizeFolder("/daily/") == "daily")
    }

    @Test func sanitizeFolder_emptySegments_collapsed() {
        // "Inbox//voice" should become "Inbox/voice", not retain the double slash.
        #expect(ObsidianURLBuilder.sanitizeFolder("Inbox//voice") == "Inbox/voice")
    }

    @Test func sanitizeFolder_dotDotTraversal_rejected() {
        #expect(ObsidianURLBuilder.sanitizeFolder("../escape") == nil)
        #expect(ObsidianURLBuilder.sanitizeFolder("daily/../escape") == nil)
        #expect(ObsidianURLBuilder.sanitizeFolder("..") == nil)
    }

    @Test func sanitizeFolder_singleDotIsNotTraversal() {
        // "." as a path segment is harmless - it's the current directory.
        // We don't filter it, which keeps the implementation simple.
        #expect(ObsidianURLBuilder.sanitizeFolder("./daily") == "./daily")
    }

    // MARK: - build with folder

    @Test func build_noFolder_filePathIsJustNoteName() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: nil,
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let fileItem = components?.queryItems?.first(where: { $0.name == "file" })
        #expect(fileItem?.value == "2026-05-02")
    }

    @Test func build_withFolder_filePathIsFolderSlashNoteName() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: "daily",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let fileItem = components?.queryItems?.first(where: { $0.name == "file" })
        #expect(fileItem?.value == "daily/2026-05-02")
    }

    @Test func build_withNestedFolder_pathPreserved() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: "Inbox/voice",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let fileItem = components?.queryItems?.first(where: { $0.name == "file" })
        #expect(fileItem?.value == "Inbox/voice/2026-05-02")
    }

    @Test func build_withDirtyFolder_sanitizedBeforeUse() throws {
        // Leading + trailing slashes from a paste should be stripped before
        // joining with the note name.
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: "/daily/",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let fileItem = components?.queryItems?.first(where: { $0.name == "file" })
        #expect(fileItem?.value == "daily/2026-05-02")
    }

    @Test func build_withTraversalFolder_falsBackToVaultRoot() throws {
        // `..` paths shouldn't escape the vault. sanitizeFolder returns nil
        // for these, so the file path is just the note name (vault root).
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: "../escape",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let fileItem = components?.queryItems?.first(where: { $0.name == "file" })
        #expect(fileItem?.value == "2026-05-02")
    }

    @Test func build_emptyTemplate_returnsNil() {
        let output = ObsidianURLBuilder.build(
            text: "hello",
            template: "",
            folder: "daily",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        )
        #expect(output == nil)
    }

    @Test func build_clipboardFlagAndAppendTrue_alwaysPresent() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: "daily",
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        let components = URLComponents(url: output.url, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map(\.name) ?? []
        #expect(names.contains("clipboard"))
        let appendItem = components?.queryItems?.first(where: { $0.name == "append" })
        #expect(appendItem?.value == "true")
    }

    @Test func build_clipboardText_endsInNewline() throws {
        let output = try #require(ObsidianURLBuilder.build(
            text: "hello",
            template: "{date}",
            folder: nil,
            modeName: "Default",
            presetName: nil,
            date: Self.fixedDate
        ))
        #expect(output.clipboardText.hasSuffix("\n"))
    }
}
