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
    let preset: Preset

    @State private var name: String
    @State private var promptInstructions: String
    @State private var showResetConfirmation = false

    private var isEdited: Bool {
        name != preset.name || promptInstructions != preset.promptInstructions
    }

    private var canReset: Bool {
        preset.isBuiltIn && PresetCatalog.defaultPreset(for: preset.id) != nil
    }

    init(preset: Preset, presetManager: PresetManager) {
        self.preset = preset
        self.presetManager = presetManager
        self._name = State(initialValue: preset.name)
        self._promptInstructions = State(initialValue: preset.promptInstructions)
    }

    var body: some View {
        Form {
            Section("Name") {
                if preset.isBuiltIn {
                    Text(name)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Preset Name", text: $name)
                }
            }

            Section("Category") {
                Text(preset.category)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Instructions"),
                    footer: instructionsFooter) {
                TextEditor(text: $promptInstructions)
                    .frame(minHeight: 200)
                    .font(.body.monospaced())
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
        .navigationTitle(preset.isBuiltIn ? preset.name : "Edit Preset")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePreset()
                }
                .disabled(!isEdited || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    @ViewBuilder
    private var instructionsFooter: some View {
        if preset.useSystemTemplate {
            Text("These instructions are injected into the transcription enhancer system prompt.")
        } else {
            Text("These instructions are used as the system message for the AI model.")
        }
    }

    private func savePreset() {
        var updated = preset
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.promptInstructions = promptInstructions
        updated.isEdited = true
        presetManager.updatePreset(updated)
        dismiss()
    }

    private func resetToDefault() {
        presetManager.resetToDefault(presetId: preset.id)
        dismiss()
    }
}
