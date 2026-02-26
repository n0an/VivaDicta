//
//  WhatsNewView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.26
//

import SwiftUI

struct WhatsNewView: View {
    let release: WhatsNewRelease
    let onDismiss: () -> Void

    @State private var startDate = Date.now
    @State private var visibleCount = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(startDate.distance(to: timeline.date))

            VStack(spacing: 0) {
                // App icon
                Image("VivaDictaIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Title
                VStack(spacing: 4) {
                    Text("What's New in")
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(meshGradient(t: t))

                    Text("v\(release.id).0")
                        .font(.title3.weight(.medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                // Features (scrollable)
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(release.features) { feature in
                            let index = release.features.firstIndex(where: { $0.id == feature.id }) ?? 0
                            if index < visibleCount {
                                WhatsNewFeatureRow(feature: feature)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                OnboardingPrimaryButton(title: "Continue") {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    UserDefaultsStorage.appPrivate.set(currentVersion, forKey: UserDefaultsStorage.Keys.lastSeenWhatsNewVersion)
                    onDismiss()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
        .onAppear {
            animateFeatures()
        }
    }

    private func animateFeatures() {
        for index in 0..<release.features.count {
            let delay = 0.15 + Double(index) * 0.08
            withAnimation(.spring(duration: 0.4).delay(delay)) {
                visibleCount = index + 1
            }
        }
    }

    // MARK: - Animated Mesh Gradient

    private func meshGradient(t: Float) -> MeshGradient {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
        ], colors: [
            .blue, .purple, .indigo,
            .cyan, .pink, .blue,
            .purple, .indigo, .cyan
        ])
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

#Preview {
    WhatsNewView(
        release: WhatsNewCatalog.release(for: "2.0.0")!,
        onDismiss: {}
    )
}
