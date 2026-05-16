// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

// MARK: - BlurTransition

public struct BlurTransition: Transition {
    public var radius: CGFloat
    public init(radius: CGFloat) {
        self.radius = radius
    }
    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
    }
}

public extension Transition where Self == BlurTransition {
    static func blur(radius: CGFloat) -> Self {
        BlurTransition(radius: radius)
    }
}

// MARK: - Badges

public protocol BadgeStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(_ label: AnyView) -> Body
}

struct DefaultBadgeStyle: BadgeStyle {
    var color: Color = .red
    func makeBody(_ label: AnyView) -> some View {
        label
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule(style: .continuous)
                    .fill(color)
            }
    }
}

enum BadgeStyleKey: EnvironmentKey {
    nonisolated(unsafe) static var defaultValue: any BadgeStyle = DefaultBadgeStyle()
}

public extension EnvironmentValues {
    var badgeStyle: any BadgeStyle {
        get { self[BadgeStyleKey.self] }
        set { self[BadgeStyleKey.self] = newValue }
    }
}

struct OverlayBadge<BadgeLabel: View>: ViewModifier {
    var alignment: Alignment = .topTrailing
    var label: BadgeLabel
    @Environment(\.badgeStyle) private var badgeStyle
    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                AnyView(badgeStyle.makeBody(AnyView(label)))
                    .fixedSize()
                    .alignmentGuide(alignment.horizontal) { $0[HorizontalAlignment.center] }
                    .alignmentGuide(alignment.vertical) { $0[VerticalAlignment.center] }
            }
    }
}

public extension View {
    func badge<V: View>(alignment: Alignment = .topTrailing,
                        @ViewBuilder _ content: () -> V) -> some View {
        modifier(OverlayBadge(alignment: alignment, label: content()))
    }
}

public struct FancyBadgeStyle: BadgeStyle {
    public init() {}
    var background: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.red)
                .overlay {
                    ContainerRelativeShape()
                        .fill(LinearGradient(colors: [.white, .clear],
                                             startPoint: .top, endPoint: .center))
                }
            ContainerRelativeShape()
                .strokeBorder(Color.white, lineWidth: 2)
                .shadow(radius: 2)
        }
    }

    public func makeBody(_ label: AnyView) -> some View {
        label
            .foregroundStyle(.white)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background)
            .containerShape(.capsule(style: .continuous))
    }
}

public extension View {
    func badgeStyle(_ style: any BadgeStyle) -> some View {
        environment(\.badgeStyle, style)
    }
}

public extension BadgeStyle where Self == FancyBadgeStyle {
    static var fancy: FancyBadgeStyle {
        FancyBadgeStyle()
    }
}

// MARK: - Debug

public extension View {
    @ViewBuilder
    func debugBorder() -> some View {
#if DEBUG
        border(Color.random())
#else
        self
#endif
    }
}

// MARK: - iflet

public extension View {
    @ViewBuilder
    func iflet<Value>(_ value: Value?, @ViewBuilder transform: (Value, Self) -> some View) -> some View {
        if let value {
            transform(value, self)
        } else {
            self
        }
    }
}

// MARK: - onFirstAppear

private struct OnFirstAppearModifier: ViewModifier {
    @State private var didPerform = false

    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content.onAppear {
            if !didPerform {
                didPerform = true

                action?()
            }
        }
    }
}

public extension View {
    func onFirstAppear(perform action: (() -> Void)? = nil) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }
}

// MARK: - minimizedSearch

public extension View {
    @ViewBuilder func minimizedSearch() -> some View {
        if #available(iOS 26.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else { self }
    }
}

// MARK: - glassEffectOrMaterial

struct GlassEffectOrMaterialModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive())
        } else {
            content
                .background(.ultraThinMaterial)
        }
    }
}

public extension View {
    func glassEffectOrMaterial() -> some View {
        modifier(GlassEffectOrMaterialModifier())
    }
}

// MARK: - glassEffectClear

struct GlassEffectClearModifier: ViewModifier {

    var isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *){
            content
                .glassEffect(.clear.interactive(isInteractive))
        } else {
            content
        }
    }
}

public extension View {
    func glassEffectClear(isInteractive: Bool = true) -> some View {
        modifier(GlassEffectClearModifier(isInteractive: isInteractive))
    }
}

struct GlassEffectColorModifier: ViewModifier {
    var isInteractive: Bool
    var color: Color
    var opacity: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, *){
            content
                .glassEffect(.regular.tint(color.opacity(opacity)).interactive(isInteractive))
        } else {
            content
        }
    }
}

public extension View {
    func glassEffectColor(isInteractive: Bool = true,
                          color: Color = .clear,
                          opacity: CGFloat = 1.0) -> some View {
        modifier(GlassEffectColorModifier(
            isInteractive: isInteractive,
            color: color,
            opacity: opacity))
    }
}

// MARK: - Glass Dismiss Circle
/// Dismiss/cancel button background: clear interactive glass on iOS 26+, gray circle on older.
struct GlassDismissCircleModifier: ViewModifier {
    var fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(fallback, in: .circle)
        }
    }
}

public extension View {
    func glassDismissCircle(fallback: some ShapeStyle = Color.gray.opacity(0.1)) -> some View {
        modifier(GlassDismissCircleModifier(fallback: AnyShapeStyle(fallback)))
    }
}

// MARK: - Glass FAB Circle
/// Floating action button background: regular interactive glass on iOS 26+, regular material fallback on older.
struct GlassFABCircleModifier: ViewModifier {
    var fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(fallback, in: .circle)
        }
    }
}

public extension View {
    func glassFABCircle(fallback: some ShapeStyle = .regularMaterial) -> some View {
        modifier(GlassFABCircleModifier(fallback: AnyShapeStyle(fallback)))
    }
}

// MARK: - Glass Capsule
/// Capsule background: interactive glass with optional tint on iOS 26+, solid fallback on older.
struct GlassCapsuleModifier: ViewModifier {
    var tint: Color?
    var fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                content
                    .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            } else {
                content
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            content
                .background(fallback, in: .capsule)
        }
    }
}

public extension View {
    func glassCapsule(tint: Color? = nil, fallback: some ShapeStyle = Color(.systemGray5)) -> some View {
        modifier(GlassCapsuleModifier(tint: tint, fallback: AnyShapeStyle(fallback)))
    }
}

// MARK: - Model Card Background

struct ModelCardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.background.secondary)
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.primary.opacity(0.3), lineWidth: 0.5)
                }
        }
    }
}

public extension View {
    func modelCardBackground() -> some View {
        modifier(ModelCardBackgroundModifier())
    }
}

// MARK: - ButtonStyle
// MARK: prominentButton

struct ProminentButton: ViewModifier {

    var color: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, *){
            content
                .buttonStyle(.glassProminent)
                .tint(color)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(color)
        }
    }
}

public extension View {
    func prominentButton(color: Color) -> some View {
        modifier(ProminentButton(color: color))
    }
}

// MARK: - animatedCopyButtonStyle

struct AnimatedCopyButtonStyle: ViewModifier {
    var color: Color
    var colorPressed: Color

    var isPressed: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *){
            content
                .buttonStyle(.glassProminent)
                .tint(isPressed ? colorPressed : color)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(isPressed ? colorPressed : color)
        }
    }
}

public extension View {
    func animatedCopyButtonStyle(color: Color,
                                 colorPressed: Color,
                                 isPressed: Bool) -> some View {
        modifier(AnimatedCopyButtonStyle(color: color, colorPressed: colorPressed, isPressed: isPressed))
    }
}

public struct RecordButtonButtonStyle: ButtonStyle {
    /// Trigger for bounce animation. Change this value to trigger a double bounce.
    public var bounceTrigger: Int

    public init(bounceTrigger: Int = 0) {
        self.bounceTrigger = bounceTrigger
    }

    private struct BounceValue {
        var scale: CGFloat = 1.0
    }

    public func makeBody(configuration: Configuration) -> some View {
        KeyframeAnimator(
            initialValue: BounceValue(),
            trigger: bounceTrigger
        ) { value in
            Image(systemName: "microphone.circle")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .padding(8)
                .background(.orange.gradient, in: .circle)
                .scaleEffect(configuration.isPressed ? 1.5 : value.scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                // First bounce
                SpringKeyframe(1.25, duration: 0.15, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.15, spring: .bouncy)
                // Pause
                LinearKeyframe(1.0, duration: 0.1)
                // Second bounce
                SpringKeyframe(1.25, duration: 0.15, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.15, spring: .bouncy)
            }
        }
    }
}
