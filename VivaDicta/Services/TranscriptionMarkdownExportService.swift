//
//  TranscriptionMarkdownExportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

enum TranscriptionMarkdownExportService {
    static func item(for transcription: Transcription) -> MarkdownExportItem {
        markdownItem(for: transcription, filename: markdownFilename(for: transcription))
    }

    static func items(for transcriptions: [Transcription]) -> [MarkdownExportItem] {
        var seenFilenames: [String: Int] = [:]

        return transcriptions
            .sorted { $0.timestamp > $1.timestamp }
            .map { transcription in
                let filename = uniquedFilename(
                    markdownFilename(for: transcription),
                    seenFilenames: &seenFilenames
                )
                return markdownItem(for: transcription, filename: filename)
            }
    }

    private static let exportTimestampFormat = Date.FormatStyle()
        .year()
        .month(.abbreviated)
        .day()
        .hour()
        .minute()

    private static func markdownItem(for transcription: Transcription, filename: String) -> MarkdownExportItem {
        MarkdownExportItem(
            filename: filename,
            text: generateMarkdown(for: transcription)
        )
    }

    private static func generateMarkdown(for transcription: Transcription) -> String {
        var lines: [String] = [
            "# Transcription - \(transcription.timestamp.formatted(exportTimestampFormat))",
            ""
        ]

        let metadata = metadataLines(for: transcription)
        if !metadata.isEmpty {
            lines.append(contentsOf: metadata)
            lines.append("")
        }

        lines.append("## Original")
        lines.append("")
        lines.append(transcription.text.trimmingCharacters(in: .whitespacesAndNewlines))
        lines.append("")

        for variation in sortedVariations(for: transcription) {
            let title = PresetCatalog.displayName(
                for: variation.presetId,
                fallback: variation.presetDisplayName
            )
            lines.append("## \(title)")
            lines.append("")
            lines.append(variation.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func markdownFilename(for transcription: Transcription) -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: transcription.timestamp
        )

        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0

        return "VivaDicta-\(year)-\(twoDigit(month))-\(twoDigit(day))_\(twoDigit(hour))\(twoDigit(minute))\(twoDigit(second)).md"
    }

    private static func uniquedFilename(_ filename: String, seenFilenames: inout [String: Int]) -> String {
        let duplicateCount = seenFilenames[filename, default: 0]
        seenFilenames[filename] = duplicateCount + 1

        guard duplicateCount > 0 else { return filename }
        return filenameByAppendingDuplicateIndex(duplicateCount + 1, to: filename)
    }

    private static func filenameByAppendingDuplicateIndex(_ duplicateIndex: Int, to filename: String) -> String {
        guard let extensionStartIndex = filename.lastIndex(of: ".") else {
            return "\(filename)-\(duplicateIndex)"
        }

        let basename = filename[..<extensionStartIndex]
        let extensionSuffix = filename[extensionStartIndex...]
        return "\(basename)-\(duplicateIndex)\(extensionSuffix)"
    }

    private static func metadataLines(for transcription: Transcription) -> [String] {
        var metadata: [String] = []

        if let model = transcription.transcriptionModelName, !model.isEmpty {
            metadata.append("- **Transcription Model:** \(model)")
        }

        let mode = powerModeDisplay(name: transcription.powerModeName, emoji: transcription.powerModeEmoji)
        if !mode.isEmpty {
            metadata.append("- **Mode:** \(mode)")
        }

        if transcription.audioDuration > 0 {
            metadata.append("- **Duration:** \(transcription.getDurationFormatted(transcription.audioDuration))")
        }

        if let sourceTag = transcription.sourceTag, !sourceTag.isEmpty {
            metadata.append("- **Source:** \(sourceTag)")
        }

        return metadata
    }

    private static func sortedVariations(for transcription: Transcription) -> [TranscriptionVariation] {
        (transcription.variations ?? []).sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.presetDisplayName.localizedStandardCompare(rhs.presetDisplayName) == .orderedAscending
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private static func powerModeDisplay(name: String?, emoji: String?) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedEmoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedName.isEmpty { return "" }
        if trimmedEmoji.isEmpty { return trimmedName }
        return "\(trimmedEmoji) \(trimmedName)"
    }

    private static func twoDigit(_ value: Int) -> String {
        if value < 10 {
            return "0\(value)"
        }

        return "\(value)"
    }
}
