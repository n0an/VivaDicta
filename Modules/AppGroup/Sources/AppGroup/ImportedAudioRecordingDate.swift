//
//  ImportedAudioRecordingDate.swift
//  AppGroup
//
//  Created by Anton Novoselov on 2026.11.06
//

import AVFoundation
import Foundation

/// Finds when imported audio was actually recorded, so a note shared hours
/// after a meeting can still carry the meeting time.
///
/// Sources, in order: the media's own creation metadata, then the file's
/// creation date. Read both from the file the user handed over, before it is
/// copied: a copy can reset the file dates. A date that is implausibly old, or
/// not clearly earlier than the import, is not trusted. The caller then gets
/// `nil`, never a guess.
public enum ImportedAudioRecordingDate {
    /// A date this close to the import, or later, is treated as lost: the share
    /// sheet or a copy most likely stamped the file when it was handed over.
    public static let minimumAgeAtImport: TimeInterval = 60

    /// Earlier dates come from zeroed headers (the 1904 and 1970 epochs), not from a recorder.
    public static let earliestPlausibleDate = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01T00:00:00Z

    /// Reads both sources from `url` and returns the first trustworthy date.
    public static func read(from url: URL, importedAt: Date = Date()) async -> Date? {
        let fileDate = fileCreationDate(of: url)
        let mediaDates = await mediaCreationDates(of: url)
        return resolve(mediaCreationDates: mediaDates, fileCreationDate: fileDate, importedAt: importedAt)
    }

    /// The first trustworthy media date, otherwise the file date when that one is trustworthy.
    public static func resolve(mediaCreationDates: [Date], fileCreationDate: Date?, importedAt: Date) -> Date? {
        (mediaCreationDates + [fileCreationDate].compactMap { $0 })
            .first { isTrustworthy($0, importedAt: importedAt) }
    }

    public static func isTrustworthy(_ date: Date, importedAt: Date) -> Bool {
        date >= earliestPlausibleDate && date <= importedAt.addingTimeInterval(-minimumAgeAtImport)
    }

    /// The file system creation date. Read it before copying the file.
    public static func fileCreationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    /// Creation dates stored in the media file, most authoritative first.
    ///
    /// The keys recorders write come first. `AVAsset.creationDate` can be the
    /// container's own creation time, which a re-export resets to the export
    /// moment, so it only comes after them: an export a day after the
    /// recording must not win over the recorder's date. `©day` is last, since
    /// on music it is a release date. Only full timestamps count: a bare year
    /// or day is not a recording time.
    public static func mediaCreationDates(of url: URL) async -> [Date] {
        let asset = AVURLAsset(url: url)
        var items: [AVMetadataItem] = []
        for format in (try? await asset.load(.availableMetadataFormats)) ?? [] {
            items += (try? await asset.loadMetadata(for: format)) ?? []
        }
        var containerDate: Date?
        if let item = try? await asset.load(.creationDate) {
            containerDate = await date(of: item)
        }
        return ordered(
            recorderDates: await dates(for: recorderDateIdentifiers, in: items),
            containerDate: containerDate,
            dayDates: await dates(for: [.iTunesMetadataReleaseDate], in: items)
        )
    }

    /// Ranks the media dates: recorder keys, then the container date, then `©day`. Duplicates are dropped.
    static func ordered(recorderDates: [Date], containerDate: Date?, dayDates: [Date]) -> [Date] {
        var result: [Date] = []
        for date in recorderDates + [containerDate].compactMap({ $0 }) + dayDates where !result.contains(date) {
            result.append(date)
        }
        return result
    }

    private static let recorderDateIdentifiers: [AVMetadataIdentifier] = [
        .quickTimeMetadataCreationDate,
        .id3MetadataRecordingTime,
        .quickTimeUserDataCreationDate,
        .isoUserDataDate,
    ]

    private static func dates(for identifiers: [AVMetadataIdentifier], in items: [AVMetadataItem]) async -> [Date] {
        var result: [Date] = []
        for identifier in identifiers {
            for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier) {
                if let date = await date(of: item) {
                    result.append(date)
                }
            }
        }
        return result
    }

    private static func date(of item: AVMetadataItem) async -> Date? {
        if let string = try? await item.load(.stringValue) {
            return try? Date(string, strategy: .iso8601)
        }
        return try? await item.load(.dateValue)
    }
}
