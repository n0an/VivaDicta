//
//  RewriteModesView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import SwiftUI

/// Displays a VivaMode picker and categorized preset list for AI text processing in the keyboard.
///
/// The VivaMode picker selects which AI provider/model to use. Tapping a preset triggers
/// the text processing pipeline using the selected mode's provider with the chosen preset's prompt.
///
/// When the main app session is not active, shows a prompt to open the main app.
struct RewriteModesView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.colorScheme) private var colorScheme

    let onPresetSelected: (VivaMode, String) -> Void
    let onOpenApp: () -> Void
    let onBackspace: () -> Void
    let onDeleteWord: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    @State private var presets: [Preset] = []
    @State private var selectedCategory: String?

    private var modes: [VivaMode] {
        dictationState.vivaModeManager.availableVivaModes
    }

    private var hasFavorites: Bool {
        presets.contains(where: \.isFavorite)
    }

    private var filteredPresets: [Preset] {
        if selectedCategory == KeyboardCategoryChipsView.favoritesFilter {
            return presets.filter(\.isFavorite)
        }
        guard let selectedCategory else { return presets }
        return presets.filter { $0.category == selectedCategory }
    }

    private var orderedCategories: [String] {
        let activePresets = filteredPresets
        var seen = Set<String>()
        var cats: [String] = []
        for preset in activePresets {
            if seen.insert(preset.category).inserted {
                cats.append(preset.category)
            }
        }
        return cats.sorted {
            PresetCatalog.categoryOrder.firstIndex(of: $0) ?? PresetCatalog.categoryOrder.count
            < PresetCatalog.categoryOrder.firstIndex(of: $1) ?? PresetCatalog.categoryOrder.count
        }
    }

    private var allCategories: [String] {
        var seen = Set<String>()
        var cats: [String] = []
        for preset in presets {
            if seen.insert(preset.category).inserted {
                cats.append(preset.category)
            }
        }
        return cats.sorted {
            PresetCatalog.categoryOrder.firstIndex(of: $0) ?? PresetCatalog.categoryOrder.count
            < PresetCatalog.categoryOrder.firstIndex(of: $1) ?? PresetCatalog.categoryOrder.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if dictationState.isSessionActive {
                presetListView
            } else {
                openAppPromptView
            }
        }
        .frame(height: 260)
        .onAppear {
            presets = KeyboardPresetLoader.loadPresets()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            KeyboardTabToggle(dictationState: dictationState)

            VivaModePicker(
                modes: modes,
                selectedModeName: Binding(
                    get: { dictationState.vivaModeManager.selectedVivaMode.name },
                    set: { newName in
                        HapticManager.selectionChanged()
                        if let mode = modes.first(where: { $0.name == newName }) {
                            dictationState.vivaModeManager.selectedVivaMode = mode
                        }
                    }
                )
            )

            Spacer()

            HStack(spacing: 4) {
                utilityButton(icon: "space", color: .blue, action: onSpace)
                    .shadow(color: .black.opacity(0.2), radius: 6)
                utilityButton(icon: "return", color: .blue, action: onNewline)
                    .shadow(color: .black.opacity(0.2), radius: 6)
                utilityButton(icon: "delete.backward", color: .red, action: onBackspace, longHoldAction: onDeleteWord)
                    .shadow(color: .black.opacity(0.2), radius: 6)
            }
        }
    }

    // MARK: - Preset List

    private var presetListView: some View {
        VStack(spacing: 0) {
            KeyboardCategoryChipsView(
                categories: allCategories,
                selectedCategory: $selectedCategory,
                showFavorites: hasFavorites
            )
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Favorites section when no category filter is active
                    if selectedCategory == nil {
                        let favorites = presets.filter(\.isFavorite)
                        if !favorites.isEmpty {
                            presetSection(title: "Favorites", presets: favorites)
                        }
                    }

                    ForEach(orderedCategories, id: \.self) { category in
                        presetSection(
                            title: category,
                            presets: filteredPresets.filter { $0.category == category }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private func presetSection(title: String, presets: [Preset]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(presets) { preset in
                    presetCell(preset)
                }
            }
        }
        .background(Color.white.opacity(0.001))
    }

    private func presetCell(_ preset: Preset) -> some View {
        Button {
            HapticManager.mediumImpact()
            onPresetSelected(dictationState.vivaModeManager.selectedVivaMode, preset.id)
        } label: {
            HStack(spacing: 6) {
                if !preset.isBuiltIn {
                    Capsule()
                        .fill(.orange)
                        .frame(width: 3, height: 18)
                }

                PresetIconView(icon: preset.icon)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !preset.presetDescription.isEmpty {
                        Text(preset.presetDescription)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if preset.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.6))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                colorScheme == .dark ? Color(.quaternarySystemFill).opacity(0.5) : Color.white,
                in: .rect(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Open App Prompt

    private var openAppPromptView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Open VivaDicta")
                .font(.system(size: 18, weight: .semibold))

            Text("Launch the app to use AI text processing")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.mediumImpact()
                onOpenApp()
            } label: {
                Label("Open VivaDicta", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .prominentButton(color: .orange)
            .padding(.vertical, 4)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Utility Button

    enum UtilityButtonPlacement {
        case first
        case mid
        case last
    }

    @ViewBuilder
    private func utilityButton(
        icon: String,
        color: Color,
        placement: UtilityButtonPlacement = .mid,
        action: @escaping () -> Void,
        longHoldAction: (() -> Void)? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            RepeatableButton(action: action, longHoldAction: longHoldAction) {
                utilityButtonLabel(icon: icon)
                    .frame(width: 36, height: 20)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .glassEffect(.regular.tint(color.opacity(0.3)).interactive())
            .padding(.trailing, placement == .first ? 4 : 0)
            .padding(.trailing, placement == .last ? 0 : 4)
        } else {
            RepeatableButton(action: action, longHoldAction: longHoldAction) {
                utilityButtonLabel(icon: icon)
                    .frame(width: 40, height: 24)
                    .background(color.opacity(0.5), in: .capsule(style: .continuous))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    private func utilityButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .contentShape(.rect)
    }
}

// MARK: - Category Chips (Keyboard-local)

/// Horizontal scrollable category filter chips for the keyboard preset list.
///
/// Self-contained version for the keyboard extension since `CategoryChipsView`
/// from the main app is not in the keyboard target.
private struct KeyboardCategoryChipsView: View {
    static let favoritesFilter = "__favorites__"

    let categories: [String]
    @Binding var selectedCategory: String?
    var showFavorites: Bool = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                if showFavorites {
                    chip(title: "Favorites", icon: "heart.fill", isSelected: selectedCategory == Self.favoritesFilter) {
                        selectedCategory = Self.favoritesFilter
                    }
                }
                ForEach(categories, id: \.self) { category in
                    chip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func chip(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button { HapticManager.selectionChanged(); action() } label: {
                HStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                    }
                    Text(title)
                }
                .font(.system(size: 13))
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
            }
            .buttonStyle(.plain)
            .glassEffect(
                isSelected
                ? .regular.tint(Color.pink.opacity(0.6)).interactive()
                : .regular.interactive()
            )
        } else {
            Button { HapticManager.selectionChanged(); action() } label: {
                HStack(spacing: 4) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                    }
                    Text(title)
                }
                .font(.system(size: 13))
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }
}
