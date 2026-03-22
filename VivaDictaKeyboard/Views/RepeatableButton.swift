//
//  RepeatableButton.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.22
//

import SwiftUI

/// A button that fires its action repeatedly while held down.
///
/// On tap: fires once. On long press and hold: fires repeatedly
/// with a configurable interval after an initial delay.
struct RepeatableButton<Label: View>: View {
    let action: () -> Void
    let initialDelay: Duration
    let repeatInterval: Duration
    @ViewBuilder let label: () -> Label

    @State private var timer: Timer?
    @State private var isPressed = false

    init(
        initialDelay: Duration = .milliseconds(400),
        repeatInterval: Duration = .milliseconds(80),
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.initialDelay = initialDelay
        self.repeatInterval = repeatInterval
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
                            // Switch to fast repeat
                            timer = Timer.scheduledTimer(
                                withTimeInterval: repeatInterval.timeInterval,
                                repeats: true
                            ) { _ in
                                action()
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        timer?.invalidate()
                        timer = nil
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
