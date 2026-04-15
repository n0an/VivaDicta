//
//  ChatInputBar.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI

/// Text input bar with send/stop button for the chat.
struct ChatInputBar: View {
    struct LeadingAction {
        let systemImage: String
        let accessibilityLabel: String
        let isArmed: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    @Binding var text: String
    var isStreaming: Bool
    var isBusy: Bool = false
    var placeholder: String = "Ask about this note..."
    var leadingActions: [LeadingAction] = []
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var isFocused: Bool
    @State private var areLeadingActionsExpanded = false
    @Namespace private var leadingActionsGlassNamespace

    private let leadingActionsAnimation = Animation.spring(response: 0.24, dampingFraction: 0.84)

    var body: some View {
        if #available(iOS 26, *) {
            glassInputBar
        } else {
            legacyInputBar
        }
    }

    @available(iOS 26, *)
    private var glassInputBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                leadingActionsView

                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                Button {
                    if isStreaming {
                        onStop()
                    } else {
                        onSend()
                    }
                } label: {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isStreaming)
                .padding(8)
                .glassEffect(
                    .regular
                        .tint(canSend || isStreaming ? Color.accentColor : .secondary)
                        .interactive(true),
                    in: .circle
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.18), radius: 8, y: -3)
        }
    }

    private var legacyInputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            leadingActionsView

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 20))

            Button {
                if isStreaming {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend || isStreaming ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend && !isStreaming)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.18), radius: 8, y: -3)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming && !isBusy
    }

    private func leadingActionGlassID(_ leadingAction: LeadingAction) -> String {
        "chat-tool-\(leadingAction.systemImage)"
    }

    @ViewBuilder
    private var leadingActionsView: some View {
        Group {
            if leadingActions.count > 1 {
                if areLeadingActionsExpanded {
                    HStack(spacing: 6) {
                        ForEach(Array(leadingActions.enumerated()), id: \.offset) { _, leadingAction in
                            leadingActionIconButton(leadingAction)
                        }
                    }
                } else {
                    leadingActionsClusterButton
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(leadingActions.enumerated()), id: \.offset) { _, leadingAction in
                        leadingActionIconButton(leadingAction)
                    }
                }
            }
        }
        .animation(leadingActionsAnimation, value: areLeadingActionsExpanded)
    }

    @ViewBuilder
    private var leadingActionsClusterButton: some View {
        let armedAction = leadingActions.first(where: \.isArmed)
        let iconName = armedAction?.systemImage ?? "wrench.and.screwdriver"
        let accessibilityLabel = armedAction?.accessibilityLabel ?? "Chat tools"
        let clusterGlassID = armedAction.map(leadingActionGlassID) ?? "chat-tools-cluster"

        Button {
            withAnimation(leadingActionsAnimation) {
                areLeadingActionsExpanded.toggle()
            }
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(areLeadingActionsExpanded || armedAction != nil ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .contentTransition(.symbolEffect(.replace))
                    .glassEffect(
                        .regular
                            .tint(
                                areLeadingActionsExpanded || armedAction != nil
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.25)
                            )
                            .interactive(true),
                        in: .circle
                    )
                    .glassEffectID(clusterGlassID, in: leadingActionsGlassNamespace)
                    .glassEffectTransition(.matchedGeometry)
            } else {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(areLeadingActionsExpanded || armedAction != nil ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        areLeadingActionsExpanded || armedAction != nil
                            ? Color.accentColor
                            : Color(.systemGray5)
                    )
                    .clipShape(.circle)
            }
        }
        .buttonStyle(.plain)
        .disabled(isStreaming || isBusy)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(areLeadingActionsExpanded ? "Expanded" : "Collapsed")
    }

    @ViewBuilder
    private func leadingActionIconButton(_ leadingAction: LeadingAction) -> some View {
        Button {
            withAnimation(leadingActionsAnimation) {
                leadingAction.action()
                areLeadingActionsExpanded = false
            }
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: leadingAction.systemImage)
                    .font(.headline)
                    .foregroundStyle(leadingAction.isArmed ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .glassEffect(
                        .regular
                            .tint(leadingAction.isArmed ? Color.accentColor : Color.secondary.opacity(0.25))
                            .interactive(true),
                        in: .circle
                    )
                    .glassEffectID(leadingActionGlassID(leadingAction), in: leadingActionsGlassNamespace)
            } else {
                Image(systemName: leadingAction.systemImage)
                    .font(.headline)
                    .foregroundStyle(leadingAction.isArmed ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background(leadingAction.isArmed ? Color.accentColor : Color(.systemGray5))
                    .clipShape(.circle)
            }
        }
        .buttonStyle(.plain)
        .disabled(!leadingAction.isEnabled || isStreaming || isBusy)
        .accessibilityLabel(leadingAction.accessibilityLabel)
        .accessibilityValue(leadingAction.isArmed ? "Enabled" : "Disabled")
    }
}
