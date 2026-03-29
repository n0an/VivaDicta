//
//  PresetSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import SwiftUI

struct PresetSettings: View {
    var presetManager: PresetManager

    @State private var showCreatePreset = false
    @State private var filter: PresetFilter = .all
    @State private var selectedCategory: String?
    @State private var searchText = ""

    private var typeFilteredPresets: [Preset] {
        let byType: [Preset] = switch filter {
        case .all: presetManager.presets
        case .system: presetManager.presets.filter(\.isBuiltIn)
        case .custom: presetManager.presets.filter { !$0.isBuiltIn }
        }
        guard !searchText.isEmpty else { return byType }
        return byType.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.presetDescription.localizedStandardContains(searchText)
        }
    }

    private var allCategories: [String] {
        var seen = Set<String>()
        return typeFilteredPresets.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    private var filteredPresets: [Preset] {
        if selectedCategory == CategoryChipsView.favoritesFilter {
            return typeFilteredPresets.filter(\.isFavorite)
        }
        guard let selectedCategory else { return typeFilteredPresets }
        return typeFilteredPresets.filter { $0.category == selectedCategory }
    }

    private var filteredCategories: [String] {
        var seen = Set<String>()
        return filteredPresets.compactMap { preset in
            if seen.contains(preset.category) { return nil }
            seen.insert(preset.category)
            return preset.category
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(PresetFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                CategoryChipsView(
                    categories: allCategories,
                    selectedCategory: $selectedCategory,
                    showFavorites: presetManager.hasFavorites
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if selectedCategory == nil {
                let favorites = typeFilteredPresets.filter(\.isFavorite)
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { preset in
                            NavigationLink(value: preset) {
                                PresetRowView(preset: preset, onToggleFavorite: {
                                    presetManager.toggleFavorite(presetId: preset.id)
                                })
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !preset.isBuiltIn {
                                    Button("Delete", role: .destructive) {
                                        deletePreset(preset)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ForEach(filteredCategories, id: \.self) { category in
                Section(category) {
                    ForEach(filteredPresets.filter { $0.category == category }) { preset in
                        NavigationLink(value: preset) {
                            PresetRowView(preset: preset, onToggleFavorite: {
                                presetManager.toggleFavorite(presetId: preset.id)
                            })
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !preset.isBuiltIn {
                                Button("Delete", role: .destructive) {
                                    deletePreset(preset)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search presets")
        .onChange(of: filter) { _, _ in
            HapticManager.selectionChanged()
            selectedCategory = nil
        }
        .onChange(of: presetManager.hasFavorites) {
            if !presetManager.hasFavorites && selectedCategory == CategoryChipsView.favoritesFilter {
                selectedCategory = nil
            }
        }
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationTitle("AI Presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Preset", systemImage: "plus") {
                    HapticManager.mediumImpact()
                    showCreatePreset = true
                }
            }
        }
        .navigationDestination(isPresented: $showCreatePreset) {
            PresetFormView(presetManager: presetManager)
        }
    }

    private func deletePreset(_ preset: Preset) {
        HapticManager.mediumImpact()
        presetManager.deletePreset(preset)
    }
}

enum PresetFilter: String, CaseIterable, Identifiable {
    case all, system, custom

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .system: "System"
        case .custom: "Custom"
        }
    }
}

private struct PresetRowView: View {
    let preset: Preset
    var onToggleFavorite: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if !preset.isBuiltIn {
                Capsule()
                    .fill(.orange)
                    .frame(width: 4)
            }

            PresetIconView(icon: preset.icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.headline)

                if !preset.presetDescription.isEmpty {
                    Text(preset.presetDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if preset.isEdited {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onToggleFavorite {
                Button {
                    HapticManager.lightImpact()
                    onToggleFavorite()
                } label: {
                    Image(systemName: preset.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(preset.isFavorite ? .red : .secondary.opacity(0.4))
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
