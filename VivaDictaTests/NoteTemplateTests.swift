//
//  NoteTemplateTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.09.30
//

import Foundation
import Testing
@testable import VivaDicta

struct NoteTemplateTests {

    /// 2026-09-30 07:05:09 in the current time zone - `NoteTemplate` reads
    /// components with a Gregorian calendar in the current time zone too.
    static let fixedDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 30
        components.hour = 7
        components.minute = 5
        components.second = 9
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static func values(text: String = "Hello world",
                       original: String = "hello world") -> NoteTemplate.Values {
        NoteTemplate.Values(
            date: fixedDate,
            text: text,
            original: original,
            mode: "Default",
            preset: "Summary",
            id: "ABC-123",
            markdown: "# Doc"
        )
    }

    // MARK: - Placeholders

    @Test func expand_dateAndTimePlaceholders() {
        let result = NoteTemplate.expand("{date} {time} {yyyy}/{MM}/{dd} {HH}{mm}{ss}", values: Self.values())
        #expect(result == "2026-09-30 07:05 2026/09/30 070509")
    }

    @Test func expand_contentPlaceholders() {
        let result = NoteTemplate.expand("{text}|{original}|{mode}|{preset}|{id}|{markdown}", values: Self.values())
        #expect(result == "Hello world|hello world|Default|Summary|ABC-123|# Doc")
    }

    @Test func expand_unknownTokensAreKept() {
        let result = NoteTemplate.expand("{foo} {date} {} {", values: Self.values())
        #expect(result == "{foo} 2026-09-30 {} {")
    }

    @Test func expand_doubleBraceStillExpandsInnerToken() {
        let result = NoteTemplate.expand("{{text}}", values: Self.values(text: "x"))
        #expect(result == "{x}")
    }

    @Test func expand_valuesAreNeverReExpanded() {
        let result = NoteTemplate.expand("{text}", values: Self.values(text: "see {date} and {id}"))
        #expect(result == "see {date} and {id}")
    }

    @Test func expand_placeholdersAreCaseSensitive() {
        // `MM` is month, `mm` is minute.
        let result = NoteTemplate.expand("{MM}-{mm}", values: Self.values())
        #expect(result == "09-05")
    }

    @Test func placeholderList_listsEveryName() {
        for name in NoteTemplate.placeholderNames {
            #expect(NoteTemplate.placeholderList.contains("{\(name)}"))
        }
    }

    // MARK: - URL escaping

    @Test func urlEscaping_encodesReservedAndNonASCII() {
        let result = NoteTemplate.expand("data={text}", values: Self.values(text: "Привет & a/b=c?"), escaping: .url)
        #expect(result == "data=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%26%20a%2Fb%3Dc%3F")
    }

    @Test func urlEscaping_leavesTemplateLiteralsAlone() {
        let result = NoteTemplate.expand("obsidian://open?file=Daily%2F{date}&prepend={text}",
                                         values: Self.values(text: "a b"),
                                         escaping: .url)
        #expect(result == "obsidian://open?file=Daily%2F2026-09-30&prepend=a%20b")
    }

    @Test func urlEscaping_encodesNewlines() {
        let result = NoteTemplate.expand("{text}", values: Self.values(text: "line1\nline2"), escaping: .url)
        #expect(result == "line1%0Aline2")
    }

    // MARK: - Filename escaping

    @Test func filenameEscaping_replacesSeparatorsAndLineBreaks() {
        let result = NoteTemplate.expand("{text}", values: Self.values(text: "a/b\\c:d\ne\tf"), escaping: .filename)
        #expect(result == "a-b-c-d e f")
    }

    @Test func filenameEscaping_keepsTemplateSlashes() {
        let result = NoteTemplate.expand("Daily/{date}", values: Self.values(), escaping: .filename)
        #expect(result == "Daily/2026-09-30")
    }
}
