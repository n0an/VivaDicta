// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

/// Loading overlay - a centered `ProgressView` over a dimmed background.
/// Applied conditionally via `.loadingOverlay(if:)`.
private struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        // The dim layer is itself a hit-testable view, so
                        // it swallows taps and keeps the underlying content
                        // uninteractive while the overlay is showing.
                        Color.black.opacity(0.25)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    .ignoresSafeArea()
                }
            }
    }
}

public extension View {
    /// Overlay a centered progress indicator over a dimmed background when
    /// `isLoading` is true. The dim layer is hit-testable and absorbs taps,
    /// so the underlying content is uninteractive while loading.
    func loadingOverlay(if isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}

#Preview("Loading overlay - on") {
    VStack(spacing: 20) {
        Text("Some content")
        Button("Tap me") {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(if: true)
}

#Preview("Loading overlay - off") {
    VStack(spacing: 20) {
        Text("Some content")
        Button("Tap me") {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(if: false)
}
