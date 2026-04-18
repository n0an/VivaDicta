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
        if coordinator.isRecordingRaw {
            throw RecordAndReturnIntentError.alreadyInProgress
        }

        switch coordinator.transcriptionStatus {
        case .recording, .transcribing, .enhancing:
            // Another session is already mid-flight. Returning its result would
            // violate the intent's "starts recording ... and returns the note" contract.
            throw RecordAndReturnIntentError.alreadyInProgress
        case .idle, .completed, .error:
            // `.completed` / `.error` are stale leftovers from a previous in-app
            // session (the main-app path never resets them; only the keyboard
            // consumer does). The poll loop only reacts to terminal states once
            // it has observed an active session this run, so it's safe to leave
            // the stale status alone here and kick off a new recording.
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
        var consecutiveIdleTicks = 0

        while Date() < deadline {
            try Task.checkCancellation()

            let status = coordinator.transcriptionStatus

            // The main app never writes `.recording` to `transcriptionStatus`;
            // it flips `isRecording` on the coordinator instead and only mutates
            // the status when transcription begins. Check both so cancels during
            // the recording phase itself still unblock the poll loop.
            if coordinator.isRecordingRaw || status == .transcribing || status == .enhancing {
                sawActiveSession = true
            }

            // Only treat `.error` as a failure once we've observed an active
            // session this run - otherwise stale `.error` from a previous
            // in-app failure would fire on the first poll tick before the main
            // app has processed the Darwin start-request notification.
            if sawActiveSession && status == .error {
                let message = coordinator.getAndConsumeTranscriptionErrorMessage()
                    ?? String(localized: "Transcription failed.")
                throw RecordAndReturnIntentError.failed(message)
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
            // without producing a new row, the user cancelled. Debounce across a
            // few consecutive ticks: when the user taps Stop in-app, the main
            // app synchronously flips `isRecording = false` and only then kicks
            // off an async task that writes `.transcribing` to status - so for
            // one to two poll ticks we legitimately observe `!isRecording &&
            // status == .idle`. Real cancels persist indefinitely.
            if sawActiveSession && !coordinator.isRecordingRaw && status == .idle {
                consecutiveIdleTicks += 1
                if consecutiveIdleTicks >= 6 {
                    throw RecordAndReturnIntentError.cancelled
                }
            } else {
                consecutiveIdleTicks = 0
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
