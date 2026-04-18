//
//  RecordAndReturnTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents
import Foundation

struct RecordAndReturnTranscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Record and Get Note"
    static let description = IntentDescription(
        "Starts recording in VivaDicta, waits for you to stop, and returns the transcribed note for use in other shortcut actions.",
        categoryName: "Notes",
        searchKeywords: ["record", "dictate", "transcribe", "note", "obsidian"],
        resultValueName: "Recorded Note"
    )

    static let openAppWhenRun: Bool = true

    /// Overall wait budget for the whole flow: user recording + transcription + optional AI enhancement.
    private static let maxWaitSeconds: TimeInterval = 180

    @Dependency var dataController: DataController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TranscriptionEntity> & ProvidesDialog {
        let coordinator = AppGroupCoordinator.shared
        let startTime = Date()
        let previousLatestId = try dataController.transcriptions(limit: 1).first?.id

        // `transcriptionStatus` stays `.idle` during the recording phase (the
        // main app flips `isRecording` instead). Guard against that case too
        // so starting this intent mid-recording doesn't silently latch onto
        // the existing session and return its note.
        if coordinator.isRecording {
            throw RecordAndReturnIntentError.alreadyInProgress
        }

        switch coordinator.transcriptionStatus {
        case .recording, .transcribing, .enhancing:
            // Another session is already mid-flight. Returning its result would
            // violate the intent's "starts recording ... and returns the note" contract.
            throw RecordAndReturnIntentError.alreadyInProgress
        case .error:
            // Drain the stale error message from the previous session before we
            // start a new one - otherwise the poll loop's first tick would see
            // `.error` and throw the old message as if it just happened.
            _ = coordinator.getAndConsumeTranscriptionErrorMessage()
            coordinator.requestStartRecordingFromControl()
        case .idle, .completed:
            // `.completed` is a stale leftover from a previous in-app session
            // (the main-app path never resets it; only the keyboard consumer does).
            // Treat it as idle and kick off a new recording.
            coordinator.requestStartRecordingFromControl()
        }

        let entity = try await waitForNewTranscription(
            after: startTime,
            previousLatestId: previousLatestId,
            coordinator: coordinator
        )

        return .result(
            value: entity,
            dialog: "\(entity.text(withPrefix: 80))"
        )
    }

    @MainActor
    private func waitForNewTranscription(
        after startTime: Date,
        previousLatestId: UUID?,
        coordinator: AppGroupCoordinator
    ) async throws -> TranscriptionEntity {
        let deadline = Date().addingTimeInterval(Self.maxWaitSeconds)
        var sawActiveSession = false

        while Date() < deadline {
            try Task.checkCancellation()

            let status = coordinator.transcriptionStatus

            if status == .error {
                let message = coordinator.getAndConsumeTranscriptionErrorMessage()
                    ?? String(localized: "Transcription failed.")
                throw RecordAndReturnIntentError.failed(message)
            }

            // The main app never writes `.recording` to `transcriptionStatus`;
            // it flips `isRecording` on the coordinator instead and only mutates
            // the status when transcription begins. Check both so cancels during
            // the recording phase itself still unblock the poll loop.
            if coordinator.isRecording || status == .transcribing || status == .enhancing {
                sawActiveSession = true
            }

            if sawActiveSession,
               let latest = try dataController.transcriptions(limit: 1).first,
               latest.id != previousLatestId,
               latest.timestamp > startTime,
               // `.idle` is accepted alongside `.completed` because the keyboard
               // consumer can race ahead and reset status to `.idle` between the
               // save and our poll tick. Don't "tighten" this to `.completed` only.
               status == .completed || status == .idle {
                // `sawActiveSession` is required so a CloudKit-synced row from
                // another device (VivaDictaMac) during the wait can't satisfy
                // `timestamp > startTime` and be returned as this intent's result.
                return latest.entity
            }

            // If we've observed an active session and it dropped back to `.idle`
            // without producing a new row, the user cancelled.
            if sawActiveSession && status == .idle {
                throw RecordAndReturnIntentError.cancelled
            }

            try await Task.sleep(for: .milliseconds(500))
        }

        throw RecordAndReturnIntentError.timedOut
    }
}

enum RecordAndReturnIntentError: Error, CustomLocalizedStringResourceConvertible {
    case failed(String)
    case timedOut
    case cancelled
    case alreadyInProgress

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failed(let message):
            "Recording failed: \(message)"
        case .timedOut:
            "Timed out waiting for the recording to finish."
        case .cancelled:
            "Recording was cancelled."
        case .alreadyInProgress:
            "A recording is already in progress in VivaDicta. Stop it first, then try again."
        }
    }
}
