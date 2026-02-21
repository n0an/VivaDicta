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

    private var filteredPresets: [Preset] {
        switch filter {
        case .all:
            presetManager.presets
        case .system:
            presetManager.presets.filter(\.isBuiltIn)
        case .custom:
            presetManager.presets.filter { !$0.isBuiltIn }
        }
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
            }

            ForEach(filteredCategories, id: \.self) { category in
                Section(category) {
                    ForEach(filteredPresets.filter { $0.category == category }) { preset in
                        NavigationLink(value: preset) {
                            PresetRowView(preset: preset)
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
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationTitle("Presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Preset", systemImage: "plus") {
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

private enum PresetFilter: String, CaseIterable, Identifiable {
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: preset.icon)
                .font(.system(size: 14))
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.headline)

                if preset.isEdited {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
