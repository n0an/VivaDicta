//
//  AdvancedSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.08
//

import SwiftUI
import AppGroup

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

    @AppStorage(UserDefaultsStorage.Keys.isChatEnabled)
    private var isChatEnabled: Bool = true

    @AppStorage(UserDefaultsStorage.Keys.isLiveTranslationEnabled)
    private var isLiveTranslationEnabled: Bool = true

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

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Chats", isOn: $isChatEnabled)
                        .onChange(of: isChatEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Show chat buttons on the main screen and in note detail. Disable to hide chat entry points across the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Live Translation", isOn: $isLiveTranslationEnabled)
                        .onChange(of: isLiveTranslationEnabled) { _, _ in
                            HapticManager.selectionChanged()
                        }
                    Text("Show the Live Translation button in the main screen toolbar. Disable to hide it if you don't use live translation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Features")
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
