//
//  AppGroupCoordinatorSessionTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import AppGroup

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
        let sut = makeCoordinator()

        sut.activateKeyboardSession(timeoutSeconds: 60)

        #expect(sut.isKeyboardSessionActive == true)
    }

    @Test func deactivateKeyboardSession_clearsState() {
        let sut = makeCoordinator()
        sut.activateKeyboardSession(timeoutSeconds: 60)

        sut.deactivateKeyboardSession()

        #expect(sut.isKeyboardSessionActive == false)
    }

    @Test func isKeyboardSessionActive_notActivated_false() {
        let sut = makeCoordinator()

        #expect(sut.isKeyboardSessionActive == false)
    }

    @Test func isKeyboardSessionActive_activated_true() {
        let sut = makeCoordinator()

        sut.activateKeyboardSession(timeoutSeconds: 300)

        #expect(sut.isKeyboardSessionActive == true)
    }

    // MARK: - Refresh Session Expiry

    @Test func refreshSessionExpiry_extendsTimeout() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let sut = AppGroupCoordinator(userDefaults: defaults)

        sut.activateKeyboardSession(timeoutSeconds: 10)
        let oldExpiry = defaults.double(forKey: "keyboardSessionExpiryTime")

        // Small delay to ensure new expiry is later
        sut.refreshKeyboardSessionExpiry(timeoutSeconds: 60)
        let newExpiry = defaults.double(forKey: "keyboardSessionExpiryTime")

        #expect(newExpiry >= oldExpiry)
    }

    @Test func refreshSessionExpiry_inactiveSession_noOp() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let sut = AppGroupCoordinator(userDefaults: defaults)

        sut.refreshKeyboardSessionExpiry(timeoutSeconds: 60)

        let expiry = defaults.double(forKey: "keyboardSessionExpiryTime")
        #expect(expiry == 0)
    }

    // MARK: - Settings Flags

    @Test func settingsFlags_defaultValues() {
        let sut = makeCoordinator()

        #expect(sut.isSmartFormattingOnPasteEnabled == true)
        #expect(sut.isKeepTranscriptInClipboardEnabled == false)
        #expect(sut.isSpeakerDiarizationEnabled == false)
        #expect(sut.isKeyboardHapticFeedbackEnabled == true)
        #expect(sut.isKeyboardSoundFeedbackEnabled == true)
    }

    @Test func settingsFlags_setAndGet() {
        let sut = makeCoordinator()

        sut.isSmartFormattingOnPasteEnabled = false
        #expect(sut.isSmartFormattingOnPasteEnabled == false)

        sut.isKeepTranscriptInClipboardEnabled = true
        #expect(sut.isKeepTranscriptInClipboardEnabled == true)

        sut.isSpeakerDiarizationEnabled = true
        #expect(sut.isSpeakerDiarizationEnabled == true)

        sut.isKeyboardHapticFeedbackEnabled = false
        #expect(sut.isKeyboardHapticFeedbackEnabled == false)

        sut.isKeyboardSoundFeedbackEnabled = false
        #expect(sut.isKeyboardSoundFeedbackEnabled == false)
    }
}
