//
//  KeyboardViewControllerDarwin.swift
//  VivaDictaKeyboard
//
//  Extension for Darwin Notification handling
//

import Foundation
import UIKit
import KeyboardKit
import os

extension KeyboardViewController {

    // MARK: - Darwin Notification Handling

    func setupDarwinNotificationObservers() {
        // Observe recording started notification for immediate UI update
        AppGroupCoordinator.shared.observeRecordingStarted { [weak self] in
            Task { @MainActor in
                self?.logger.info("📱 Received recordingStarted notification - updating UI immediately")
                self?.appStateViewModel.isRecording = true
            }
        }

        // Observe recording stopped notification for immediate UI update
        AppGroupCoordinator.shared.observeRecordingStopped { [weak self] in
            Task { @MainActor in
                self?.logger.info("📱 Received recordingStopped notification - updating UI immediately")
                self?.appStateViewModel.isRecording = false
            }
        }

        // Observe transcription ready notification
        AppGroupCoordinator.shared.observeTranscriptionReady { [weak self] in
            Task { @MainActor in
                self?.logger.info("📱 Received transcriptionReady notification")
                self?.handleTranscriptionReady()
            }
        }

        // Observe recording error notification
        AppGroupCoordinator.shared.observeRecordingError { [weak self] in
            Task { @MainActor in
                self?.logger.info("📱 Received recordingError notification")
                // Reset recording state on error
                self?.appStateViewModel.isRecording = false
            }
        }
    }

    private func handleTranscriptionReady() {
        // Read transcribed text from shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: AppGroupConfig.appGroupId)
        if let transcribedText = sharedDefaults?.string(forKey: "lastTranscription") {
            logger.info("📝 Inserting transcribed text: \(transcribedText.prefix(50))...")

            // Insert the transcribed text
            textDocumentProxy.insertText(transcribedText)

            // Clear the transcription from UserDefaults
            sharedDefaults?.removeObject(forKey: "lastTranscription")
            sharedDefaults?.synchronize()
        }
    }
}