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

//extension KeyboardViewController {
//
//    // MARK: - Darwin Notification Handling
//
//    func setupDarwinNotificationObservers() {
//        // Observe recording started notification for immediate UI update
//        AppGroupCoordinator.shared.observeRecordingStarted { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received recordingStarted notification - updating UI immediately")
//                self?.appStateViewModel.isRecording = true
//
//                // Cancel recording timeout since recording started successfully
//                self?.recordingCoordinator.cancelRecordingTimeout()
//            }
//        }
//
//        // Observe recording stopped notification for immediate UI update
//        AppGroupCoordinator.shared.observeRecordingStopped { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received recordingStopped notification - updating UI immediately")
//                self?.appStateViewModel.isRecording = false
//
//                // Transition to processing state
//                self?.keyboardStateManager.stopRecording()
//                self?.keyboardStateManager.processingStage = .waitingToStart
//                self?.viewWillSetupKeyboardView()
//            }
//        }
//
//        // Observe transcription started notification
//        AppGroupCoordinator.shared.observeTranscriptionStarted { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received transcriptionStarted notification")
//                self?.keyboardStateManager.processingStage = .transcribing
//
//                // Force UI update if in processing state
//                if self?.keyboardStateManager.viewState == .processing {
//                    self?.viewWillSetupKeyboardView()
//                }
//            }
//        }
//
//        // Observe transcription ended notification
//        AppGroupCoordinator.shared.observeTranscriptionEnded { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received transcriptionEnded notification")
//                // Just log for now, AI enhancement starts next
//            }
//        }
//
//        // Observe AI enhancement started notification
//        AppGroupCoordinator.shared.observeAIEnhancementStarted { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received aiEnhancementStarted notification")
//                self?.keyboardStateManager.processingStage = .enhancingWithAI
//
//                // Force UI update if in processing state
//                if self?.keyboardStateManager.viewState == .processing {
//                    self?.viewWillSetupKeyboardView()
//                }
//            }
//        }
//
//        // Observe AI enhancement ended notification
//        AppGroupCoordinator.shared.observeAIEnhancementEnded { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received aiEnhancementEnded notification")
//                self?.keyboardStateManager.processingStage = .completed
//            }
//        }
//
//        // Observe transcription ready notification
//        AppGroupCoordinator.shared.observeTranscriptionReady { [weak self] in
//            Task { @MainActor in
//                self?.logger.info("📱 Received transcriptionReady notification")
//                self?.handleTranscriptionReady()
//
//                // Return to idle state
//                self?.keyboardStateManager.finishProcessing()
//                self?.viewWillSetupKeyboardView()
//            }
//        }
//
//        // Observe recording error notification
//        AppGroupCoordinator.shared.observeRecordingError { [weak self] in
//            Task { @MainActor in
//                guard let self = self else { return }
//
//                self.logger.info("📱 Received recordingError notification")
//
//                // Reset recording state on error
//                self.appStateViewModel.isRecording = false
//
//                // Show error in processing view then return to idle
//                self.keyboardStateManager.processingStage = .error("Recording failed")
//
//                // If not in processing state, transition to it to show error
//                if self.keyboardStateManager.viewState != .processing {
//                    self.keyboardStateManager.viewState = .processing
//                    self.viewWillSetupKeyboardView()
//                }
//
//                // Return to idle after showing error
//                Task { @MainActor in
//                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
//                    self.keyboardStateManager.cancelRecording()
//                    self.viewWillSetupKeyboardView()
//                }
//            }
//        }
//    }
//
//    private func handleTranscriptionReady() {
//        // Check if the recording was canceled - if so, don't insert text
//        if keyboardStateManager.didCancelRecording {
//            logger.info("📝 Transcription ready but recording was canceled - not inserting text")
//
//            // Clear the flag and transcription
//            keyboardStateManager.didCancelRecording = false
//            UserDefaultsStorage.shared.removeObject(forKey: "lastTranscription")
//            UserDefaultsStorage.shared.synchronize()
//            return
//        }
//
//        // Read transcribed text from shared UserDefaults
//        if let transcribedText = UserDefaultsStorage.shared.string(forKey: "lastTranscription") {
//            logger.info("📝 Inserting transcribed text...")
//
//            // Safely insert the transcribed text with error handling
//            guard !transcribedText.isEmpty else {
//                logger.info("📝 Transcribed text is empty, skipping insertion")
//                UserDefaultsStorage.shared.removeObject(forKey: "lastTranscription")
//                UserDefaultsStorage.shared.synchronize()
//                return
//            }
//
//            // Insert the transcribed text
//            textDocumentProxy.insertText(transcribedText)
//
//            // Clear the transcription from UserDefaults
//            UserDefaultsStorage.shared.removeObject(forKey: "lastTranscription")
//            UserDefaultsStorage.shared.synchronize()
//
//            logger.info("📝 Successfully inserted transcription")
//        } else {
//            logger.info("📝 No transcription found in UserDefaults")
//        }
//    }
//}
