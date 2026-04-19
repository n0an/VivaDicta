//
//  PendingAppIntentAction.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.19
//

#if !os(macOS)
import Foundation

@MainActor
final class PendingAppIntentAction {
    static let shared = PendingAppIntentAction()
    private init() {}

    enum Action {
        case search
        case askAI
    }

    private(set) var pending: Action?

    func enqueue(_ action: Action) {
        pending = action
        drain()
    }

    func clear() {
        pending = nil
    }

    func drain() {
        guard let appState = SceneDelegate.appState, let action = pending else { return }
        switch action {
        case .search:
            appState.shouldFocusSearch = true
        case .askAI:
            appState.shouldShowChats = true
        }
        pending = nil
    }
}
#endif
