//
//  RepeatableButton.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.22
//

import SwiftUI

/// A button that fires its action repeatedly while held down.
///
/// Three phases when held:
/// 1. **Tap** (0ms): fires `action` once
/// 2. **Character repeat** (after `initialDelay`): fires `action` at `repeatInterval`
/// 3. **Long hold** (after `longHoldThreshold`): fires `longHoldAction` at `longHoldInterval`
///
/// If no `longHoldAction` is provided, phase 2 continues indefinitely.
struct RepeatableButton<Label: View>: View {
    let action: () -> Void
    let longHoldAction: (() -> Void)?
    let initialDelay: Duration
    let repeatInterval: Duration
    let longHoldThreshold: Duration
    let longHoldInterval: Duration
    @ViewBuilder let label: () -> Label

    @State private var timer: Timer?
    @State private var longHoldTimer: Timer?
    @State private var isPressed = false

    init(
        initialDelay: Duration = .milliseconds(400),
        repeatInterval: Duration = .milliseconds(80),
        longHoldThreshold: Duration = .seconds(2),
        longHoldInterval: Duration = .milliseconds(150),
        action: @escaping () -> Void,
        longHoldAction: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.longHoldAction = longHoldAction
        self.initialDelay = initialDelay
        self.repeatInterval = repeatInterval
        self.longHoldThreshold = longHoldThreshold
        self.longHoldInterval = longHoldInterval
        self.label = label
    }

    var body: some View {
        label()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        HapticManager.lightImpact()

                        // Start repeating after initial delay
                        timer = Timer.scheduledTimer(
                            withTimeInterval: initialDelay.timeInterval,
                            repeats: false
                        ) { _ in
                            // Phase 2: character-by-character repeat
                            timer = Timer.scheduledTimer(
                                withTimeInterval: repeatInterval.timeInterval,
                                repeats: true
                            ) { _ in
                                action()
                            }

                            // Schedule phase 3 transition if longHoldAction provided
                            if let longHoldAction {
                                let delay = longHoldThreshold.timeInterval - initialDelay.timeInterval
                                longHoldTimer = Timer.scheduledTimer(
                                    withTimeInterval: max(delay, 0),
                                    repeats: false
                                ) { _ in
                                    // Switch to word-by-word
                                    timer?.invalidate()
                                    timer = Timer.scheduledTimer(
                                        withTimeInterval: longHoldInterval.timeInterval,
                                        repeats: true
                                    ) { _ in
                                        longHoldAction()
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        timer?.invalidate()
                        timer = nil
                        longHoldTimer?.invalidate()
                        longHoldTimer = nil
                    }
            )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
