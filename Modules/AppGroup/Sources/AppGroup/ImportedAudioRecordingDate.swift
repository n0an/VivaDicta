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
    /// `AVAsset.creationDate` can be the container's own creation time, which a
    /// re-export resets to the export moment, so the date keys recorders write
    /// are read as well. Only full timestamps count: a bare year or day (for
    /// example a song's release year) is not a recording time.
    public static func mediaCreationDates(of url: URL) async -> [Date] {
        let asset = AVURLAsset(url: url)
        var dates: [Date] = []
        if let item = try? await asset.load(.creationDate), let date = await date(of: item) {
            dates.append(date)
        }
        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        for format in formats {
            let items = (try? await asset.loadMetadata(for: format)) ?? []
            for identifier in recordingDateIdentifiers {
                for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier) {
                    if let date = await date(of: item), !dates.contains(date) {
                        dates.append(date)
                    }
                }
            }
        }
        return dates
    }

    private static let recordingDateIdentifiers: [AVMetadataIdentifier] = [
        .quickTimeMetadataCreationDate,
        .quickTimeUserDataCreationDate,
        .isoUserDataDate,
        .iTunesMetadataReleaseDate, // ©day: a re-exported file often keeps the recording time here
        .id3MetadataRecordingTime,
    ]

    private static func date(of item: AVMetadataItem) async -> Date? {
        if let string = try? await item.load(.stringValue) {
            return try? Date(string, strategy: .iso8601)
        }
        return try? await item.load(.dateValue)
    }
}
