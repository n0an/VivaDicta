//
//  FolderExportComposerTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.30
//

import Foundation
import AppGroup
import Testing
@testable import VivaDicta

struct FolderExportComposerTests {

    private let values = NoteTemplateTests.values()

    // MARK: - Paths

    @Test func relativePath_defaultTemplateMatchesLegacyName() {
        let path = FolderExportComposer.relativePath(template: UserDefaultsStorage.defaultFolderExportFilenameTemplate,
                                                     values: values)
        #expect(path == ["VivaDicta-2026-09-30_070509.md"])
    }

    @Test func relativePath_slashCreatesSubfolders() {
        let path = FolderExportComposer.relativePath(template: "Daily/{yyyy}/{date}", values: values)
        #expect(path == ["Daily", "2026", "2026-09-30.md"])
    }

    @Test func relativePath_traversalAndHiddenComponentsAreDropped() {
        let path = FolderExportComposer.relativePath(template: "../../.obsidian//./{date}", values: values)
        #expect(path == ["obsidian", "2026-09-30.md"])
    }

    @Test func relativePath_valueSlashesNeverCreateFolders() {
        let path = FolderExportComposer.relativePath(template: "{text}",
                                                     values: NoteTemplateTests.values(text: "../etc/passwd"))
        #expect(path == ["-etc-passwd.md"])
    }

    @Test func relativePath_keepsKnownExtensions() {
        #expect(FolderExportComposer.relativePath(template: "Notes.MD", values: values) == ["Notes.MD"])
        #expect(FolderExportComposer.relativePath(template: "log.txt", values: values) == ["log.txt"])
        #expect(FolderExportComposer.relativePath(template: "a.markdown", values: values) == ["a.markdown"])
        #expect(FolderExportComposer.relativePath(template: "v1.2", values: values) == ["v1.2.md"])
    }

    @Test func relativePath_longNamesAreTruncated() throws {
        let long = String(repeating: "a", count: 500)
        let path = try #require(FolderExportComposer.relativePath(template: "{text}",
                                                                  values: NoteTemplateTests.values(text: long)))
        let name = try #require(path.last)
        #expect(name == String(repeating: "a", count: FolderExportComposer.maxComponentLength) + ".md")
    }

    @Test func relativePath_wideCharactersStayUnderByteLimit() throws {
        for character in ["字", "👍", "я"] {
            let long = String(repeating: character, count: 500)
            let path = try #require(FolderExportComposer.relativePath(template: "{text}",
                                                                      values: NoteTemplateTests.values(text: long)))
            let name = try #require(path.last)
            #expect(name.utf8.count <= 255)
            #expect(name.hasSuffix(".md"))
            #expect(name.dropLast(3).allSatisfy { String($0) == character })
        }
    }

    @Test func relativePath_emptyResultReturnsNil() {
        #expect(FolderExportComposer.relativePath(template: "///", values: values) == nil)
        #expect(FolderExportComposer.relativePath(template: "{text}",
                                                  values: NoteTemplateTests.values(text: "")) == nil)
    }

    // MARK: - Merge

    private let startA = FolderExportComposer.startMarker(id: "A")
    private let endA = FolderExportComposer.endMarker(id: "A")
    private let startB = FolderExportComposer.startMarker(id: "B")
    private let endB = FolderExportComposer.endMarker(id: "B")

    @Test func merge_intoEmptyFileWritesSingleBlock() {
        let result = FolderExportComposer.merge(existing: nil, entry: "first", id: "A", mode: .append)
        #expect(result == "\(startA)\nfirst\n\(endA)\n")
    }

    @Test func merge_appendAddsAtEnd() {
        let existing = "# Day\n\nold\n\n\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "new", id: "B", mode: .append)
        #expect(result == "# Day\n\nold\n\n\(startB)\nnew\n\(endB)\n")
    }

    @Test func merge_prependAddsAtTop() {
        let existing = "\n\nold\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "new", id: "B", mode: .prepend)
        #expect(result == "\(startB)\nnew\n\(endB)\n\nold\n")
    }

    @Test func merge_prependGoesBelowFrontmatter() {
        let existing = "---\ntags: daily\n---\n\nold\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "new", id: "B", mode: .prepend)
        #expect(result == "---\ntags: daily\n---\n\(startB)\nnew\n\(endB)\n\nold\n")
    }

    @Test func merge_prependIntoFrontmatterOnlyFile() {
        let existing = "---\ntags: daily\n---\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "new", id: "B", mode: .prepend)
        #expect(result == "---\ntags: daily\n---\n\(startB)\nnew\n\(endB)\n")
    }

    @Test func merge_sameIDReplacesBlockInPlace() {
        let existing = "top\n\n\(startA)\nold\n\(endA)\n\nbottom\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "updated", id: "A", mode: .prepend)
        #expect(result == "top\n\n\(startA)\nupdated\n\(endA)\n\nbottom\n")
    }

    @Test func merge_otherBlocksAreUntouched() {
        let existing = "\(startA)\none\n\(endA)\n"
        let result = FolderExportComposer.merge(existing: existing, entry: "two", id: "B", mode: .append)
        #expect(result == "\(startA)\none\n\(endA)\n\n\(startB)\ntwo\n\(endB)\n")
    }

    @Test func merge_entryIsTrimmed() {
        let result = FolderExportComposer.merge(existing: nil, entry: "\n\n  x  \n\n", id: "A", mode: .append)
        #expect(result == "\(startA)\nx\n\(endA)\n")
    }

    // MARK: - Frontmatter

    @Test func splitFrontmatter_withoutFrontmatterReturnsBody() {
        let split = FolderExportComposer.splitFrontmatter("# Title\n---\n")
        #expect(split.frontmatter == nil)
        #expect(split.body == "# Title\n---\n")
    }

    @Test func splitFrontmatter_unclosedIsNotFrontmatter() {
        let split = FolderExportComposer.splitFrontmatter("---\ntags: x\n")
        #expect(split.frontmatter == nil)
    }

    @Test func splitFrontmatter_dotsCloseFrontmatter() {
        let split = FolderExportComposer.splitFrontmatter("---\na: 1\n...\nbody")
        #expect(split.frontmatter == "---\na: 1\n...")
        #expect(split.body == "body")
    }
}
