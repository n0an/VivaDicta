//
//  HapticManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.10
//

import UIKit
import SwiftUI
import CoreHaptics

/// Centralized manager for haptic feedback throughout the app
enum HapticManager {

    // MARK: - Feedback Generators (lazily initialized)

    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - CoreHaptics Engine

    private static var hapticEngine: CHHapticEngine?
    private static var engineNeedsStart = true

    // MARK: - Settings

    /// Check if haptics are enabled in app settings
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsStorage.Keys.isHapticsEnabled)
    }

    /// Check if device supports haptics
    private static var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - CoreHaptics Engine Management

    private static func createAndStartEngine() {
        guard supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.playsHapticsOnly = true

            // Handle engine reset
            hapticEngine?.resetHandler = {
                do {
                    try hapticEngine?.start()
                    engineNeedsStart = false
                } catch {
                    engineNeedsStart = true
                }
            }

            // Handle engine stopped
            hapticEngine?.stoppedHandler = { _ in
                engineNeedsStart = true
            }

            try hapticEngine?.start()
            engineNeedsStart = false
        } catch {
            hapticEngine = nil
        }
    }

    private static func ensureEngineRunning() {
        guard supportsHaptics else { return }

        if hapticEngine == nil {
            createAndStartEngine()
        } else if engineNeedsStart {
            do {
                try hapticEngine?.start()
                engineNeedsStart = false
            } catch {
                // Engine failed to start
            }
        }
    }

    // MARK: - AHAP Pattern Playback

    /// Play a custom haptic pattern from an AHAP file
    /// - Parameter named: The name of the AHAP file (without extension)
    static func playPattern(named: String) {
        guard isEnabled, supportsHaptics else { return }

        ensureEngineRunning()

        guard let engine = hapticEngine,
              let url = Bundle.main.url(forResource: named, withExtension: "ahap") else {
            return
        }

        do {
            try engine.playPattern(from: url)
        } catch {
            // Fallback to standard haptic if pattern fails
            success()
        }
    }

    // MARK: - Impact Feedback

    /// Light impact - for subtle UI feedback (e.g., scroll to top, minor button taps)
    static func lightImpact() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Medium impact - for standard button taps and confirmations
    static func mediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Heavy impact - for significant actions (e.g., stop recording)
    static func heavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    /// Soft impact - for gentle feedback (e.g., expand/collapse animations)
    static func softImpact() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }

    /// Rigid impact - for crisp, sharp feedback
    static func rigidImpact() {
        guard isEnabled else { return }
        impactRigid.impactOccurred()
    }

    // MARK: - Selection Feedback

    /// Selection changed - for pickers, toggles, segmented controls
    static func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success notification - for completed operations (e.g., transcription done, copy success)
    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Warning notification - for destructive actions (e.g., delete)
    static func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Error notification - for failed operations
    static func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }
    // MARK: - Prepare (optional optimization)

    /// Prepare generators for immediate feedback (call before anticipated action)
    static func prepare() {
        guard isEnabled else { return }
        impactMedium.prepare()
        notification.prepare()
        ensureEngineRunning()
    }
}
