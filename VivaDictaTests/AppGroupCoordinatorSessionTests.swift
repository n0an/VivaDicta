//
//  AppGroupCoordinatorSessionTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct AppGroupCoordinatorSessionTests {

    // MARK: - Test Helpers

    private let suiteName = "AppGroupCoordinatorSessionTests.\(UUID().uuidString)"

    private func makeCoordinator() -> AppGroupCoordinator {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppGroupCoordinator(userDefaults: defaults)
    }

    // MARK: - Activate / Deactivate Session

    @Test func activateKeyboardSession_setsActiveAndExpiry() {
        let coordinator = makeCoordinator()

        coordinator.activateKeyboardSession(timeoutSeconds: 60)

        #expect(coordinator.isKeyboardSessionActive == true)
    }

    @Test func deactivateKeyboardSession_clearsState() {
        let coordinator = makeCoordinator()
        coordinator.activateKeyboardSession(timeoutSeconds: 60)

        coordinator.deactivateKeyboardSession()

        #expect(coordinator.isKeyboardSessionActive == false)
    }

    @Test func isKeyboardSessionActive_notActivated_false() {
        let coordinator = makeCoordinator()

        #expect(coordinator.isKeyboardSessionActive == false)
    }

    @Test func isKeyboardSessionActive_activated_true() {
        let coordinator = makeCoordinator()

        coordinator.activateKeyboardSession(timeoutSeconds: 300)

        #expect(coordinator.isKeyboardSessionActive == true)
    }

    // MARK: - Refresh Session Expiry

    @Test func refreshSessionExpiry_extendsTimeout() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let coordinator = AppGroupCoordinator(userDefaults: defaults)

        coordinator.activateKeyboardSession(timeoutSeconds: 10)
        let oldExpiry = defaults.double(forKey: "keyboardSessionExpiryTime")

        // Small delay to ensure new expiry is later
        coordinator.refreshKeyboardSessionExpiry(timeoutSeconds: 60)
        let newExpiry = defaults.double(forKey: "keyboardSessionExpiryTime")

        #expect(newExpiry >= oldExpiry)
    }

    @Test func refreshSessionExpiry_inactiveSession_noOp() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let coordinator = AppGroupCoordinator(userDefaults: defaults)

        coordinator.refreshKeyboardSessionExpiry(timeoutSeconds: 60)

        let expiry = defaults.double(forKey: "keyboardSessionExpiryTime")
        #expect(expiry == 0)
    }

    // MARK: - Settings Flags

    @Test func settingsFlags_defaultValues() {
        let coordinator = makeCoordinator()

        #expect(coordinator.isSmartFormattingOnPasteEnabled == true)
        #expect(coordinator.isKeepTranscriptInClipboardEnabled == false)
        #expect(coordinator.isSpeakerDiarizationEnabled == false)
        #expect(coordinator.isKeyboardHapticFeedbackEnabled == true)
        #expect(coordinator.isKeyboardSoundFeedbackEnabled == true)
    }

    @Test func settingsFlags_setAndGet() {
        let coordinator = makeCoordinator()

        coordinator.isSmartFormattingOnPasteEnabled = false
        #expect(coordinator.isSmartFormattingOnPasteEnabled == false)

        coordinator.isKeepTranscriptInClipboardEnabled = true
        #expect(coordinator.isKeepTranscriptInClipboardEnabled == true)

        coordinator.isSpeakerDiarizationEnabled = true
        #expect(coordinator.isSpeakerDiarizationEnabled == true)

        coordinator.isKeyboardHapticFeedbackEnabled = false
        #expect(coordinator.isKeyboardHapticFeedbackEnabled == false)

        coordinator.isKeyboardSoundFeedbackEnabled = false
        #expect(coordinator.isKeyboardSoundFeedbackEnabled == false)
    }
}
