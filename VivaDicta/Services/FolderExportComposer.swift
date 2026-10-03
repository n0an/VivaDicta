//
//  FolderExportComposer.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.09.30
//

import Foundation

/// What folder export does when the target file already exists.
nonisolated enum FolderExportWriteMode: String, CaseIterable, Identifiable, Sendable {
    /// One file per note; re-exporting the same note overwrites it.
    case replace
    /// Add the note as a block at the end of the file.
    case append
    /// Add the note as a block at the top of the file, below YAML frontmatter.
    case prepend

    nonisolated static let `default`: FolderExportWriteMode = .replace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .replace: "Replace file"
        case .append: "Add to end"
        case .prepend: "Add to top"
        }
    }
}

/// Pure path and content logic for folder export, kept free of file IO so it
/// can be unit tested.
nonisolated enum FolderExportComposer {

    /// Longest allowed path component before the extension, in characters.
    nonisolated static let maxComponentLength = 120

    /// Longest allowed path component before the extension, in UTF-8 bytes.
    /// Keeps `{text}` in a file name from hitting the 255-byte filesystem
    /// limit: CJK and emoji take 3-4 bytes per character, so the character
    /// limit alone is not enough.
    nonisolated static let maxComponentBytes = 240

    private nonisolated static let markdownExtensions = [".md", ".markdown", ".txt"]

    /// Expands a file-name template into relative path components (subfolders
    /// followed by the file name). `/` in the template creates subfolders;
    /// `/` inside a placeholder value never does. Empty, `.` and `..`
    /// components are dropped, so the result always stays inside the picked
    /// folder. `.md` is added when the name has no markdown/text extension.
    ///
    /// - Returns: `nil` when nothing usable is left (e.g. the template expands
    ///   to only slashes).
    nonisolated static func relativePath(template: String, values: NoteTemplate.Values) -> [String]? {
        let expanded = NoteTemplate.expand(template, values: values, escaping: .filename)
        var components = expanded
            .split(separator: "/")
            .map { sanitizeComponent(String($0)) }
            .filter { !$0.isEmpty }
        guard let last = components.popLast() else { return nil }

        let lowercased = last.lowercased()
        let fileExtension = markdownExtensions.first { lowercased.hasSuffix($0) && lowercased.count > $0.count }
        let base = fileExtension.map { String(last.dropLast($0.count)) } ?? last
        let fileName = truncated(base) + (fileExtension.map { String(last.suffix($0.count)) } ?? ".md")
        return components + [fileName]
    }

    private nonisolated static func sanitizeComponent(_ component: String) -> String {
        var result = component
            .replacing("\\", with: "-")
            .replacing(":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Leading dots would make `..` traversal or hidden files (`.obsidian`).
        while result.hasPrefix(".") {
            result.removeFirst()
        }
        return truncated(result).trimmingCharacters(in: .whitespaces)
    }

    /// Cuts a component to `maxComponentLength` characters and
    /// `maxComponentBytes` UTF-8 bytes, never splitting a character.
    private nonisolated static func truncated(_ component: String) -> String {
        var result = Substring(component.prefix(maxComponentLength))
        var bytes = result.utf8.count
        while bytes > maxComponentBytes, let last = result.popLast() {
            bytes -= String(last).utf8.count
        }
        return String(result)
    }

    // MARK: - Blocks

    nonisolated static func startMarker(id: String) -> String { "<!-- vivadicta:\(id) -->" }
    nonisolated static func endMarker(id: String) -> String { "<!-- /vivadicta:\(id) -->" }

    /// Wraps an entry in invisible HTML-comment markers carrying the note ID,
    /// so exporting the same note again updates its block instead of adding a
    /// duplicate.
    nonisolated static func block(id: String, entry: String) -> String {
        let body = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(startMarker(id: id))\n\(body)\n\(endMarker(id: id))"
    }

    /// Merges a note block into existing file content.
    ///
    /// - If a block with the same ID already exists, it is replaced in place,
    ///   whatever the mode.
    /// - `.append` adds the block after the existing content.
    /// - `.prepend` adds it at the top, below YAML frontmatter if present.
    /// - `.replace` returns just the block (callers normally write the full
    ///   markdown document instead and never merge).
    nonisolated static func merge(existing: String?, entry: String, id: String, mode: FolderExportWriteMode) -> String {
        let newBlock = block(id: id, entry: entry)
        let existing = existing ?? ""

        if let range = existingBlockRange(in: existing, id: id) {
            var updated = existing
            updated.replaceSubrange(range, with: newBlock)
            return updated
        }

        guard mode != .replace,
              !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return newBlock + "\n"
        }

        switch mode {
        case .replace:
            return newBlock + "\n"
        case .append:
            return trimmingTrailingNewlines(existing) + "\n\n" + newBlock + "\n"
        case .prepend:
            let (frontmatter, body) = splitFrontmatter(existing)
            let trimmedBody = trimmingLeadingNewlines(body)
            let head = frontmatter.map { $0 + "\n" } ?? ""
            let tail = trimmedBody.isEmpty ? "\n" : "\n\n" + trimmedBody
            return head + newBlock + tail
        }
    }

    private nonisolated static func existingBlockRange(in content: String, id: String) -> Range<String.Index>? {
        guard let start = content.range(of: startMarker(id: id)),
              let end = content.range(of: endMarker(id: id), range: start.upperBound..<content.endIndex) else {
            return nil
        }
        return start.lowerBound..<end.upperBound
    }

    /// Splits leading YAML frontmatter (`---` ... `---`) from the body. The
    /// returned frontmatter has no trailing newline.
    nonisolated static func splitFrontmatter(_ content: String) -> (frontmatter: String?, body: String) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first,
              first.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return (nil, content)
        }
        guard let closing = lines.dropFirst().firstIndex(where: {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == "---" || trimmed == "..."
        }) else {
            return (nil, content)
        }
        let frontmatter = lines[...closing].joined(separator: "\n")
        let body = lines[(closing + 1)...].joined(separator: "\n")
        return (frontmatter, body)
    }

    private nonisolated static func trimmingTrailingNewlines(_ text: String) -> String {
        var result = text
        while let last = result.last, last.isNewline {
            result.removeLast()
        }
        return result
    }

    private nonisolated static func trimmingLeadingNewlines(_ text: String) -> String {
        String(text.drop { $0.isNewline })
    }
}
