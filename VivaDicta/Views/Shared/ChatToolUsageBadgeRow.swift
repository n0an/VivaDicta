//
//  ChatToolUsageBadgeRow.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import SwiftUI

struct ChatToolUsageBadgeRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let didUseCrossNoteSearchTool: Bool
    let didUseWebSearchTool: Bool

    private var badges: [ChatToolUsageBadge] {
        var items: [ChatToolUsageBadge] = []

        if didUseCrossNoteSearchTool {
            items.append(
                ChatToolUsageBadge(
                    icon: "sparkle.magnifyingglass",
                    accessibilityLabel: "Other notes searched",
                    tint: .teal
                )
            )
        }

        if didUseWebSearchTool {
            items.append(
                ChatToolUsageBadge(
                    icon: "globe",
                    accessibilityLabel: "Web searched",
                    tint: .blue
                )
            )
        }

        return items
    }

    var body: some View {
        if !badges.isEmpty {
            ScrollView(.horizontal) {
                Group {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 6) {
                            badgeRow
                        }
                    } else {
                        badgeRow
                    }
                }
                .padding(.leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var badgeRow: some View {
        HStack(spacing: 6) {
            ForEach(badges) { badge in
                Image(systemName: badge.icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .glassCapsule(
                    tint: badge.tint.opacity(colorScheme == .dark ? 0.25 : 0.75),
                    fallback: badge.tint.opacity(0.3)
                )
                .accessibilityLabel(badge.accessibilityLabel)
            }
        }
    }
}

private struct ChatToolUsageBadge: Identifiable {
    let id = UUID()
    let icon: String
    let accessibilityLabel: String
    let tint: Color
}
