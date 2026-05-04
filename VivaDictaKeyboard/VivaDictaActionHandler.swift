//
//  VivaDictaActionHandler.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.05.04
//

import Foundation
import KeyboardKit

/// Custom action name for the EN/RU language toggle key.
/// Using a constant prevents typos between the layout injection site and the
/// action handler that intercepts the release gesture.
/// `nonisolated(unsafe)` because the value is an immutable string literal,
/// referenced from both the main-actor view code and the nonisolated action
/// handler override.
nonisolated(unsafe) let vivaDictaLanguageToggleActionName = "vd-lang-toggle"

/// Notification posted when the user taps the EN/RU toggle key.
/// `KeyboardCustomView` listens for this to invalidate its cached layout state.
extension Notification.Name {
    static let vivaDictaLanguageToggled = Notification.Name("VivaDictaLanguageToggled")
}

/// Standard KeyboardKit action handler with a single override:
/// intercepts release gestures on `.custom("vd-lang-toggle")` to flip
/// `AppGroupCoordinator.shared.isCurrentlyRussian`. All other actions
/// (character input, shift, backspace, globe, etc.) fall through to the
/// stock implementation.
///
/// `nonisolated` matches the base class's actor isolation. KeyboardKit's
/// `StandardActionHandler` overrides need to keep the same isolation, so
/// any UI-side work (haptics, notification post observed by SwiftUI) is
/// dispatched onto the main actor explicitly.
final class VivaDictaActionHandler: KeyboardAction.StandardActionHandler {

    nonisolated override init(
        controller: (any KeyboardController)?,
        keyboardContext: KeyboardContext,
        keyboardBehavior: any KeyboardBehavior,
        autocompleteContext: AutocompleteContext,
        autocompleteService: any AutocompleteService,
        emojiContext: EmojiContext,
        feedbackContext: FeedbackContext,
        feedbackService: any FeedbackService,
        spacebarDragGestureHandler: Gestures.SpacebarDragGestureHandler
    ) {
        super.init(
            controller: controller,
            keyboardContext: keyboardContext,
            keyboardBehavior: keyboardBehavior,
            autocompleteContext: autocompleteContext,
            autocompleteService: autocompleteService,
            emojiContext: emojiContext,
            feedbackContext: feedbackContext,
            feedbackService: feedbackService,
            spacebarDragGestureHandler: spacebarDragGestureHandler
        )
    }

    nonisolated override func handle(
        _ gesture: Keyboard.Gesture,
        on action: KeyboardAction
    ) {
        if gesture == .release,
           case .custom(let name) = action,
           name == vivaDictaLanguageToggleActionName {
            toggleLanguage()
            return
        }
        super.handle(gesture, on: action)
    }

    private nonisolated func toggleLanguage() {
        Task { @MainActor in
            let coordinator = AppGroupCoordinator.shared
            coordinator.isCurrentlyRussian.toggle()
            HapticManager.selectionChanged()
            NotificationCenter.default.post(name: .vivaDictaLanguageToggled, object: nil)
        }
    }
}
