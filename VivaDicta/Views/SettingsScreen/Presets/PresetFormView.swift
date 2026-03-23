//
//  PresetFormView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import SwiftUI

struct PresetFormView: View {
    @Environment(\.dismiss) private var dismiss

    let presetManager: PresetManager

    /// The preset being edited. `nil` for creation mode.
    private let existingPreset: Preset?

    @State private var name: String
    @State private var presetDescription: String
    @State private var category: String
    @State private var promptInstructions: String
    @State private var useSystemTemplate: Bool
    @State private var wrapInTranscriptTags: Bool
    @State private var showResetConfirmation = false

    private var isCreateMode: Bool { existingPreset == nil }

    private var isEdited: Bool {
        guard let preset = existingPreset else { return true }
        return name != preset.name || presetDescription != preset.presetDescription || category != preset.category || promptInstructions != preset.promptInstructions || useSystemTemplate != preset.useSystemTemplate || wrapInTranscriptTags != preset.wrapInTranscriptTags
    }

    private var isAssistantPreset: Bool {
        existingPreset?.id == "assistant"
    }

    private var canSave: Bool {
        if isAssistantPreset { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !promptInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if isCreateMode {
            return !presetManager.isPresetNameDuplicate(trimmedName)
        }
        return isEdited && !presetManager.isPresetNameDuplicate(trimmedName, excludingId: existingPreset?.id)
    }

    private var allCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for cat in presetManager.categories where seen.insert(cat).inserted {
            result.append(cat)
        }
        if !result.contains("Other") {
            result.append("Other")
        }
        return result
    }

    private var canReset: Bool {
        guard let preset = existingPreset else { return false }
        return preset.isBuiltIn && PresetCatalog.defaultPreset(for: preset.id) != nil
    }

    /// Edit mode: pass an existing preset.
    init(preset: Preset, presetManager: PresetManager) {
        self.existingPreset = preset
        self.presetManager = presetManager
        self._name = State(initialValue: preset.name)
        self._presetDescription = State(initialValue: preset.presetDescription)
        self._category = State(initialValue: preset.category)
        self._promptInstructions = State(initialValue: preset.promptInstructions)
        self._useSystemTemplate = State(initialValue: preset.useSystemTemplate)
        self._wrapInTranscriptTags = State(initialValue: preset.wrapInTranscriptTags)
    }

    /// Create mode: no preset provided.
    init(presetManager: PresetManager) {
        self.existingPreset = nil
        self.presetManager = presetManager
        self._name = State(initialValue: "")
        self._presetDescription = State(initialValue: "")
        self._category = State(initialValue: "Rewrite")
        self._promptInstructions = State(initialValue: "")
        self._useSystemTemplate = State(initialValue: true)
        self._wrapInTranscriptTags = State(initialValue: true)
    }

    var body: some View {
        Form {
            Section("Name") {
                if let preset = existingPreset, preset.isBuiltIn {
                    Text(name)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Preset Name", text: $name)
                }
            }

            Section("Description") {
                if let preset = existingPreset, preset.isBuiltIn {
                    Text(presetDescription)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Short description", text: $presetDescription)
                }
            }

            if isAssistantPreset {
                Section {
                    Text("This preset uses a dedicated AI assistant prompt that responds to your requests instead of cleaning up transcriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Toggle("Use System Prompt", isOn: $useSystemTemplate)
                    Toggle("Wrap in <TRANSCRIPT>", isOn: $wrapInTranscriptTags)
                }

                if let preset = existingPreset, preset.isBuiltIn {
                    Section("Category") {
                        Text(category)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(allCategories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Instructions") {
                    TextEditor(text: $promptInstructions)
                        .frame(minHeight: 200)
                        .font(.body.monospaced())
                }
            }

            if canReset {
                Section {
                    Button("Reset to Default") {
                        showResetConfirmation = true
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if !isCreateMode, let preset = existingPreset {
                ToolbarItem(placement: .principal) {
                    Button {
                        presetManager.toggleFavorite(presetId: preset.id)
                    } label: {
                        Image(systemName: presetManager.preset(for: preset.id)?.isFavorite == true ? "heart.fill" : "heart")
                            .foregroundStyle(presetManager.preset(for: preset.id)?.isFavorite == true ? .red : .secondary)
                    }
                }
            }
            if !isAssistantPreset {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreateMode ? "Add" : "Save") {
                        if isCreateMode {
                            createPreset()
                        } else {
                            savePreset()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .confirmationDialog("Reset to Default",
                            isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text("This will reset the preset instructions to the factory default.")
        }
    }

    private var navigationTitle: String {
        if isCreateMode { return "New Preset" }
        return existingPreset?.isBuiltIn == true ? (existingPreset?.name ?? "") : "Edit Preset"
    }

    private func createPreset() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPreset = Preset(
            id: "custom_\(UUID().uuidString)",
            name: trimmedName,
            icon: "✨",
            presetDescription: presetDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            promptInstructions: promptInstructions,
            useSystemTemplate: useSystemTemplate,
            wrapInTranscriptTags: wrapInTranscriptTags,
            isBuiltIn: false
        )
        presetManager.addPreset(newPreset)
        dismiss()
    }

    private func savePreset() {
        guard var updated = existingPreset else { return }
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.presetDescription = presetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.useSystemTemplate = useSystemTemplate
        updated.wrapInTranscriptTags = wrapInTranscriptTags
        if !updated.isBuiltIn {
            updated.category = category
        }
        updated.promptInstructions = promptInstructions
        updated.isEdited = true
        presetManager.updatePreset(updated)
        dismiss()
    }

    private func resetToDefault() {
        guard let preset = existingPreset else { return }
        presetManager.resetToDefault(presetId: preset.id)
        dismiss()
    }
}
