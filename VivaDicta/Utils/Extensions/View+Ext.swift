//
//  View+Ext.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI

// MARK: - BlurTransition
struct BlurTransition: Transition {
    var radius: CGFloat
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
    }
}

extension Transition where Self == BlurTransition {
    static func blur(radius: CGFloat) -> Self {
        BlurTransition(radius: radius)
    }
}

// extension View {
//    func badge<B: View>(@ViewBuilder _ badge: () -> B) -> some View {
//        overlay(alignment: .topTrailing) {
//            badge()
//                .alignmentGuide(.top) { $0.height/2 }
//                .alignmentGuide(.trailing) { $0.width/2 }
//        }
//    }
// }

// struct Badge: ViewModifier {
//    @Environment(\.badgeColor) private var badgeColor
//    func body(content: Content) -> some View {
//        content
//            .font(.caption)
//            .foregroundStyle(.white)
//            .padding(.horizontal, 5)
//            .padding(.vertical, 2)
//            .background {
//                Capsule(style: .continuous)
//                    .fill(badgeColor)
//            }
//    }
// }

// enum BadgeColorKey: EnvironmentKey {
//    static var defaultValue: Color = .blue
// }
//
// extension EnvironmentValues {
//    var badgeColor: Color {
//        get { self[BadgeColorKey.self] }
//        set { self[BadgeColorKey.self] = newValue }
//    }
// }
//
// extension View {
//    func badgeColor(_ color: Color) -> some View {
//        environment(\.badgeColor, color)
//    }
// }

// MARK: - Badges
protocol BadgeStyle {
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

extension EnvironmentValues {
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

extension View {
    func badge<V: View>(alignment: Alignment = .topTrailing,
                        @ViewBuilder _ content: () -> V) -> some View {
        modifier(OverlayBadge(alignment: alignment, label: content()))
    }
}

struct FancyBadgeStyle: BadgeStyle {
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

    func makeBody(_ label: AnyView) -> some View {
        label
            .foregroundStyle(.white)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background)
            .containerShape(.capsule(style: .continuous))
    }
}

extension View {
    func badgeStyle(_ style: any BadgeStyle) -> some View {
        environment(\.badgeStyle, style)
    }
}

extension BadgeStyle where Self == FancyBadgeStyle {
    static var fancy: FancyBadgeStyle {
        FancyBadgeStyle()
    }
}

// MARK: - Debug
extension View {
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
extension View {
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

extension View {
    func onFirstAppear(perform action: (() -> Void)? = nil) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }
}


// MARK: - minimizedSearch
extension View {
    @ViewBuilder func minimizedSearch() -> some View {
        if #available(iOS 26.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else { self }
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

extension View {
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

extension View {
    func glassEffectColor(isInteractive: Bool = true,
                          color: Color = .clear,
                          opacity: CGFloat = 1.0) -> some View {
        modifier(GlassEffectColorModifier(
            isInteractive: isInteractive,
            color: color,
            opacity: opacity))
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

extension View {
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

extension View {
    func animatedCopyButtonStyle(color: Color,
                                 colorPressed: Color,
                                 isPressed: Bool) -> some View {
        modifier(AnimatedCopyButtonStyle(color: color, colorPressed: colorPressed, isPressed: isPressed))
    }
}

struct RecordButtonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "microphone.circle")
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .padding(8)
            .background(.orange.gradient, in: .circle)
            .scaleEffect(configuration.isPressed ? 1.5 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


