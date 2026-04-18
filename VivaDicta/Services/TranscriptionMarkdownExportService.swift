//
//  TranscriptionMarkdownExportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

enum TranscriptionMarkdownExportService {
    struct Snapshot: Sendable {
        let timestamp: Date
        let text: String
        let transcriptionModelName: String?
        let powerModeDisplay: String
        let durationText: String?
        let sourceTag: String?
        let variations: [VariationSnapshot]
    }

    struct VariationSnapshot: Sendable {
        let title: String
        let sortKey: String
        let text: String
        let createdAt: Date
    }

    @MainActor static func item(for transcription: Transcription) -> MarkdownExportItem {
        item(forSnapshot: snapshot(for: transcription))
    }

    @MainActor static func items(for transcriptions: [Transcription]) -> [MarkdownExportItem] {
        items(forSnapshots: snapshots(for: transcriptions))
    }

    @MainActor static func snapshots(for transcriptions: [Transcription]) -> [Snapshot] {
        transcriptions.map(snapshot(for:))
    }

    nonisolated static func item(forSnapshot snapshot: Snapshot) -> MarkdownExportItem {
        markdownItem(for: snapshot, filename: markdownFilename(for: snapshot))
    }

    nonisolated static func items(forSnapshots snapshots: [Snapshot]) -> [MarkdownExportItem] {
        var seenFilenames: [String: Int] = [:]

        return snapshots
            .sorted { $0.timestamp > $1.timestamp }
            .map { snapshot in
                let filename = uniquedFilename(
                    markdownFilename(for: snapshot),
                    seenFilenames: &seenFilenames
                )
                return markdownItem(for: snapshot, filename: filename)
            }
    }

    nonisolated private static let exportTimestampFormat = Date.FormatStyle()
        .year()
        .month(.abbreviated)
        .day()
        .hour()
        .minute()

    @MainActor private static func snapshot(for transcription: Transcription) -> Snapshot {
        Snapshot(
            timestamp: transcription.timestamp,
            text: transcription.text,
            transcriptionModelName: transcription.transcriptionModelName,
            powerModeDisplay: powerModeDisplay(name: transcription.powerModeName, emoji: transcription.powerModeEmoji),
            durationText: transcription.audioDuration > 0 ? transcription.getDurationFormatted(transcription.audioDuration) : nil,
            sourceTag: transcription.sourceTag,
            variations: (transcription.variations ?? []).map {
                VariationSnapshot(
                    title: PresetCatalog.displayName(
                        for: $0.presetId,
                        fallback: $0.presetDisplayName
                    ),
                    sortKey: $0.presetDisplayName,
                    text: $0.text,
                    createdAt: $0.createdAt
                )
            }
        )
    }

    nonisolated private static func markdownItem(for snapshot: Snapshot, filename: String) -> MarkdownExportItem {
        MarkdownExportItem(
            filename: filename,
            text: generateMarkdown(for: snapshot)
        )
    }

    nonisolated private static func generateMarkdown(for snapshot: Snapshot) -> String {
        var lines: [String] = [
            "# Transcription - \(snapshot.timestamp.formatted(exportTimestampFormat))",
            ""
        ]

        let metadata = metadataLines(for: snapshot)
        if !metadata.isEmpty {
            lines.append(contentsOf: metadata)
            lines.append("")
        }

        let sorted = sortedVariations(for: snapshot)
        let lastVariation = sorted.last

        func appendOriginal() {
            lines.append("## Original")
            lines.append("")
            lines.append(snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        func appendVariation(_ variation: VariationSnapshot) {
            lines.append("## \(variation.title)")
            lines.append("")
            lines.append(variation.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        switch MarkdownExportContent.current {
        case .allVariations:
            appendOriginal()
            for variation in sorted {
                appendVariation(variation)
            }
        case .originalOnly:
            appendOriginal()
        case .originalAndLastVariation:
            appendOriginal()
            if let lastVariation {
                appendVariation(lastVariation)
            }
        case .lastVariationOnly:
            if let lastVariation {
                appendVariation(lastVariation)
            } else {
                appendOriginal()
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    nonisolated private static func markdownFilename(for snapshot: Snapshot) -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: snapshot.timestamp
        )

        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0

        return "VivaDicta-\(year)-\(twoDigit(month))-\(twoDigit(day))_\(twoDigit(hour))\(twoDigit(minute))\(twoDigit(second)).md"
    }

    nonisolated private static func uniquedFilename(_ filename: String, seenFilenames: inout [String: Int]) -> String {
        let duplicateCount = seenFilenames[filename, default: 0]
        seenFilenames[filename] = duplicateCount + 1

        guard duplicateCount > 0 else { return filename }
        return filenameByAppendingDuplicateIndex(duplicateCount + 1, to: filename)
    }

    nonisolated private static func filenameByAppendingDuplicateIndex(_ duplicateIndex: Int, to filename: String) -> String {
        guard let extensionStartIndex = filename.lastIndex(of: ".") else {
            return "\(filename)-\(duplicateIndex)"
        }

        let basename = filename[..<extensionStartIndex]
        let extensionSuffix = filename[extensionStartIndex...]
        return "\(basename)-\(duplicateIndex)\(extensionSuffix)"
    }

    nonisolated private static func metadataLines(for transcription: Snapshot) -> [String] {
        var metadata: [String] = []

        if let model = transcription.transcriptionModelName, !model.isEmpty {
            metadata.append("- **Transcription Model:** \(model)")
        }

        if !transcription.powerModeDisplay.isEmpty {
            metadata.append("- **Mode:** \(transcription.powerModeDisplay)")
        }

        if let durationText = transcription.durationText, !durationText.isEmpty {
            metadata.append("- **Duration:** \(durationText)")
        }

        if let sourceTag = transcription.sourceTag, !sourceTag.isEmpty {
            metadata.append("- **Source:** \(sourceTag)")
        }

        return metadata
    }

    nonisolated private static func sortedVariations(for transcription: Snapshot) -> [VariationSnapshot] {
        transcription.variations.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.sortKey.localizedStandardCompare(rhs.sortKey) == .orderedAscending
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    nonisolated private static func powerModeDisplay(name: String?, emoji: String?) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedEmoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedName.isEmpty { return "" }
        if trimmedEmoji.isEmpty { return trimmedName }
        return "\(trimmedEmoji) \(trimmedName)"
    }

    nonisolated private static func twoDigit(_ value: Int) -> String {
        if value < 10 {
            return "0\(value)"
        }

        return "\(value)"
    }
}
