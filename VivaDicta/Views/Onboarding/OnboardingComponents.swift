//
//  OnboardingComponents.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

// MARK: - Feature Row

struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}


// MARK: - Primary Button

struct OnboardingPrimaryButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void

    init(title: String, icon: String? = nil, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .bottom,
                    endPoint: .top
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary Button

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
//                .colorInvert()
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.gray.opacity(0.3).gradient, in: .rect(cornerRadius: 16))
                
        }
        .buttonStyle(.plain)

    }
}

// MARK: - Instruction Row

struct OnboardingInstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(.init(text))
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Info Box

struct OnboardingInfoBox: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    let textColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(textColor)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(textColor)

            Spacer()
        }
        .padding()
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - App Icon View

struct OnboardingAppIcon: View {
    let gradient: [Color]
    let size: CGFloat

    init(gradient: [Color] = [.blue], size: CGFloat = 100) {
        self.gradient = gradient
        self.size = size
    }

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: size * 0.4))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: size * 0.22)
            )
            .compositingGroup()
            .shadow(color: gradient.first?.opacity(0.8) ?? .clear, radius: 20)
    }
}

// MARK: - Privacy Card

struct OnboardingPrivacyCard: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.green.opacity(1), .red.opacity(1))
                    
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Card Container

struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) {
            content
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Page Indicator

struct OnboardingPageIndicator: View {
    @Namespace private var dotAnimation

    let currentPage: OnboardingPage

    private let dotSize: CGFloat = 8
    private let lineWidth: CGFloat = 28
    private let spacing: CGFloat = 12

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(OnboardingPage.allCases) { page in
                if page == currentPage {
                    // Selected: line/pill shape
                    Capsule()
                        .fill(Color.blue)
                        .matchedGeometryEffect(id: "dot", in: dotAnimation)
                        .frame(width: lineWidth, height: dotSize)

                } else {
                    // Not selected: dot
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: currentPage)
    }
}

// MARK: - Previews

#Preview("Feature Row") {
    VStack(spacing: 16) {
        OnboardingFeatureRow(
            icon: "checkmark.shield.fill",
            iconColor: .green,
            text: "Complete privacy - your data stays on device"
        )
        OnboardingFeatureRow(
            icon: "waveform",
            iconColor: .blue,
            text: "Advanced transcription models for perfect accuracy"
        )
        
        OnboardingPrivacyCard(
            title: "Privacy Guaranteed",
            description: "Audio never leaves your device unless you choose cloud models."
        )
    }
    .padding()
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        OnboardingPrimaryButton(title: "Get Started", action: {})
        OnboardingPrimaryButton(title: "Enable Microphone", icon: "mic.fill", color: .green, action: {})
        
        
        
        OnboardingSecondaryButton(title: "Set Up Later", action: {})
    }
    .padding()
}

#Preview("App Icon") {
    VStack(spacing: 32) {
        OnboardingAppIcon(gradient: [.blue, .blue.opacity(0.7)])
        OnboardingAppIcon(gradient: [.pink, .cyan], size: 80)
    }
}

#Preview("Page Indicator") {
    VStack(spacing: 24) {
        OnboardingPageIndicator(currentPage: .welcome)
        OnboardingPageIndicator(currentPage: .microphone)
        OnboardingPageIndicator(currentPage: .keyboard)
    }
    .padding()
}
