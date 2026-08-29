//
//  VivaDictaActionHandler.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.05.04
//

import Foundation
import AppGroup
import KeyboardKit

/// Custom action name for the in-keyboard language cycle key.
/// Using a constant prevents typos between the layout injection site and the
/// action handler that intercepts the release gesture.
/// `nonisolated` (without `(unsafe)`) is correct: file-scope `let`s default to
/// `@MainActor` under Swift 6 strict concurrency, but this string literal is
/// `Sendable` and read from both the main-actor view and the nonisolated
/// action handler override, so we explicitly opt out of the actor.
nonisolated let vivaDictaLanguageToggleActionName = "vd-lang-toggle"

/// Notification posted when the user taps the language cycle key.
/// `KeyboardCustomView` listens for this to invalidate its cached layout state.
extension Notification.Name {
    static let vivaDictaLanguageToggled = Notification.Name("VivaDictaLanguageToggled")
}

/// Standard KeyboardKit action handler with a single override:
/// intercepts release gestures on `.custom("vd-lang-toggle")` and advances
/// `AppGroupCoordinator.shared.currentKeyboardLanguage` to the next enabled
/// language in canonical order. All other actions (character input, shift,
/// backspace, globe, etc.) fall through to the stock implementation.
///
/// The class is `nonisolated` to match the base class. The target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it every member -
/// including the inherited initializers - would be `@MainActor` and clash with
/// the nonisolated declarations they override. Any UI-side work (haptics,
/// notification post observed by SwiftUI) is dispatched onto the main actor
/// explicitly.
///
/// The class deliberately declares no initializers. It adds no stored
/// properties, so it inherits every designated and convenience initializer
/// from `StandardKeyboardActionHandler` - including the `init(controller:)` used at
/// the call site. Re-declaring the designated initializer only to forward it
/// verbatim would re-break on every KeyboardKit release that adds a
/// dependency to it (10.4 added `keyboardAppContext`).
nonisolated final class VivaDictaActionHandler: StandardKeyboardActionHandler {

    override func handle(
        _ gesture: Keyboard.Gesture,
        on action: KeyboardAction
    ) {
        if gesture == .release,
           case .custom(let name) = action,
           name == vivaDictaLanguageToggleActionName {
            cycleToNextLanguage()
            return
        }
        super.handle(gesture, on: action)
    }

    /// Advances `currentKeyboardLanguage` to the next enabled language using
    /// `KeyboardLanguage.allCases` order. No-op when fewer than 2 languages
    /// are enabled (the toggle key shouldn't even be visible in that case,
    /// but guard anyway).
    private func cycleToNextLanguage() {
        Task { @MainActor in
            let coordinator = AppGroupCoordinator.shared
            let order = KeyboardLanguage.allCases.filter {
                coordinator.enabledKeyboardLanguages.contains($0)
            }
            guard order.count >= 2 else { return }
            let current = coordinator.currentKeyboardLanguage
            let currentIndex = order.firstIndex(of: current) ?? 0
            let nextIndex = (currentIndex + 1) % order.count
            coordinator.currentKeyboardLanguage = order[nextIndex]
            HapticManager.selectionChanged()
            NotificationCenter.default.post(name: .vivaDictaLanguageToggled, object: nil)
        }
    }
}
