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
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - CoreHaptics Engine

    private static var hapticEngine: CHHapticEngine?
    private static var engineNeedsStart = true

    // MARK: - Settings

    /// Check if haptics are enabled in app settings
    private static var isEnabled: Bool {
        UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isHapticsEnabled)
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

    // MARK: - Custom Haptic Patterns

    /// Celebration - celebratory haptic with fade-out buzz and sparkles (used for onboarding completion)
    static func celebration() {
        guard isEnabled, supportsHaptics else { return }

        ensureEngineRunning()

        guard let engine = hapticEngine else {
            // Fallback to standard haptic
            notification.notificationOccurred(.success)
            return
        }
        
        var events = [CHHapticEvent]()
        var curves = [CHHapticParameterCurve]()

        do {
            // create one continuous buzz that fades out
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)

            let start = CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1)
            let end = CHHapticParameterCurve.ControlPoint(relativeTime: 1.5, value: 0)

            let parameter = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [start, end], relativeTime: 0)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [sharpness, intensity], relativeTime: 0, duration: 1.5)
            events.append(event)
            curves.append(parameter)
        }

        for _ in 1...16 {
            // make some sparkles
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: TimeInterval.random(in: 0.1...1))
            events.append(event)
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            notification.notificationOccurred(.success)

        }
    }

    /// Heartbeat pattern - for transcription/enhancement completion
    static func heartbeat() {
        playPattern(named: "TranscriptionComplete")
    }

    // MARK: - AHAP Pattern Playback

    /// Play a custom haptic pattern from an AHAP file
    /// - Parameter named: The name of the AHAP file (without extension)
    private static func playPattern(named: String) {
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
            notification.notificationOccurred(.success)
        }
    }

    // MARK: - Impact Feedback

    /// Light impact - for subtle UI feedback (e.g., scroll to top, edit mode buttons, swipe actions, copy, navigation buttons)
    static func lightImpact() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Medium impact - for standard button taps and confirmations
    static func mediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Heavy impact - for significant actions
    static func heavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    // MARK: - Selection Feedback

    /// Selection changed - for pickers, toggles, select all/deselect all, item selection
    static func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success notification - not used
//    static func success() {
//        guard isEnabled else { return }
//        notification.notificationOccurred(.success)
//    }

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
