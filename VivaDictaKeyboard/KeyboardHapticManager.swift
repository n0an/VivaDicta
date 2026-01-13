
//
//  HapticManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.13
//

import UIKit
import SwiftUI
import CoreHaptics

/// Centralized manager for haptic feedback throughout the app
enum KeyboardHapticManager {

    // MARK: - Feedback Generators (lazily initialized)

    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Settings

    /// Check if haptics are enabled in app settings
    private static var isEnabled: Bool {
        UserDefaultsStorage.shared.bool(forKey: AppGroupCoordinator.isHapticsEnabled)
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


    // MARK: - Selection Feedback

    /// Selection changed - for pickers, toggles, select all/deselect all, item selection
    static func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback
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
}

