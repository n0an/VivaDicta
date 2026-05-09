//
//  AdvancedSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.08
//

import SwiftUI

enum AppendWithVoiceStyle: String, CaseIterable, Identifiable {
    case toolbar
    case floatingButton

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toolbar: "Toolbar"
        case .floatingButton: "Floating Button"
        }
    }
}

struct AdvancedSettingsView: View {
    @AppStorage(UserDefaultsStorage.Keys.appendWithVoiceStyle)
    private var appendWithVoiceStyleRaw: String = AppendWithVoiceStyle.toolbar.rawValue

    private var appendWithVoiceStyle: Binding<AppendWithVoiceStyle> {
        Binding(
            get: {
                AppendWithVoiceStyle(rawValue: appendWithVoiceStyleRaw) ?? .toolbar
            },
            set: { newValue in
                appendWithVoiceStyleRaw = newValue.rawValue
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Append with Voice", selection: appendWithVoiceStyle) {
                        ForEach(AppendWithVoiceStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .onChange(of: appendWithVoiceStyle.wrappedValue) { _, _ in
                        HapticManager.selectionChanged()
                    }
                    Text("Choose how to access the Append with Voice action on a note. Toolbar puts it inside the pencil menu in the bottom action bar; Floating Button shows a microphone shortcut in the bottom-right corner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Note Detail")
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AdvancedSettingsView()
    }
}
#endif
