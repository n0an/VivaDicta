//
//  RecordingTime.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.06
//

import AppGroup
import Foundation

/// What VivaDicta knows about when the audio of a new note was recorded.
/// Resolved into `Transcription.recordedAt` when the note is saved.
nonisolated enum RecordingTime: Sendable, Equatable {
    /// Known exactly: a live recording's start, or a date already resolved
    /// where the audio entered (the share and action extensions).
    case known(Date)

    /// A file imported in the app. The file creation date was read from the
    /// original before the copy; the media metadata is read from the copy,
    /// which has the same bytes.
    case imported(fileCreationDate: Date?, importedAt: Date)

    /// Reads a file the user picked, before it is copied.
    static func importing(from originalURL: URL, at importedAt: Date = Date()) -> RecordingTime {
        .imported(fileCreationDate: ImportedAudioRecordingDate.fileCreationDate(of: originalURL), importedAt: importedAt)
    }

    /// The recording date to store, or `nil` when it is unknown or not trustworthy.
    func resolve(audioURL: URL) async -> Date? {
        switch self {
        case .known(let date):
            return date
        case .imported(let fileCreationDate, let importedAt):
            let mediaDates = await ImportedAudioRecordingDate.mediaCreationDates(of: audioURL)
            return ImportedAudioRecordingDate.resolve(
                mediaCreationDates: mediaDates,
                fileCreationDate: fileCreationDate,
                importedAt: importedAt
            )
        }
    }
}
