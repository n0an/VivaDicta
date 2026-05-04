//
//  KeyboardLanguagesSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.04
//

import SwiftUI

/// Settings UI for picking which languages the custom keyboard should offer.
///
/// Renders one disclosure row labeled by the currently-enabled languages,
/// expanding to a multi-select list of all `KeyboardLanguage` cases. Persists
/// the selection through `AppGroupCoordinator` and refuses to disable the
/// last enabled language (English is the floor when the user tries to clear
/// the set entirely).
///
/// When 2+ languages are enabled, the keyboard extension shows an in-keyboard
/// cycle key next to space; that's communicated via the row subtitle so the
/// user knows what enabling extra languages actually does.
struct KeyboardLanguagesSettingsView: View {

    @Binding var enabledLanguages: Set<KeyboardLanguage>

    var body: some View {
        DisclosureGroup {
            ForEach(KeyboardLanguage.allCases) { language in
                Toggle(isOn: binding(for: language)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.displayName)
                            .font(.body)
                        Text(language.layoutDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Languages")
                    .font(.body)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Returns a binding that reflects whether `language` is currently enabled
    /// and writes through to `AppGroupCoordinator` on change. Refuses to
    /// disable the last remaining language - if the user tries to switch off
    /// the only enabled toggle, we silently keep it on.
    private func binding(for language: KeyboardLanguage) -> Binding<Bool> {
        Binding(
            get: { enabledLanguages.contains(language) },
            set: { newValue in
                var updated = enabledLanguages
                if newValue {
                    updated.insert(language)
                } else {
                    // Don't allow disabling the last enabled language.
                    guard updated.count > 1 else { return }
                    updated.remove(language)
                }
                guard updated != enabledLanguages else { return }
                HapticManager.selectionChanged()
                enabledLanguages = updated
                AppGroupCoordinator.shared.enabledKeyboardLanguages = updated
            }
        )
    }

    /// Comma-separated native names of the enabled languages, in canonical
    /// `KeyboardLanguage.allCases` order.
    private var summaryText: String {
        let names = KeyboardLanguage.allCases
            .filter { enabledLanguages.contains($0) }
            .map(\.displayName)
        return names.isEmpty ? KeyboardLanguage.english.displayName : names.joined(separator: ", ")
    }
}
