//
//  HapticManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.01.10
//

import UIKit
import SwiftUI

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

    // MARK: - Settings

    /// Check if haptics are enabled in app settings
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsStorage.Keys.isHapticsEnabled)
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

    // MARK: - Semantic Actions (High-Level API)

    /// Haptic for starting recording
    static func recordingStarted() {
        mediumImpact()
    }

    /// Haptic for stopping recording
    static func recordingStopped() {
        heavyImpact()
    }

    /// Haptic for canceling an action
    static func actionCancelled() {
        lightImpact()
    }

    /// Haptic for transcription/enhancement completion
    static func processingCompleted() {
        success()
    }

    /// Haptic for copy to clipboard
    static func copiedToClipboard() {
        success()
    }

    /// Haptic for delete action
    static func itemDeleted() {
        warning()
    }

    /// Haptic for download completion
    static func downloadCompleted() {
        success()
    }

    /// Haptic for toggle state change
    static func toggleChanged() {
        selectionChanged()
    }

    /// Haptic for picker/menu selection
    static func pickerSelectionChanged() {
        selectionChanged()
    }

    /// Haptic for button expand/collapse
    static func buttonToggled() {
        softImpact()
    }

    /// Haptic for play/pause audio
    static func playbackToggled() {
        lightImpact()
    }

    /// Haptic for error occurrence
    static func errorOccurred() {
        error()
    }

    // MARK: - Prepare (optional optimization)

    /// Prepare generators for immediate feedback (call before anticipated action)
    static func prepare() {
        guard isEnabled else { return }
        impactMedium.prepare()
        notification.prepare()
    }
}
