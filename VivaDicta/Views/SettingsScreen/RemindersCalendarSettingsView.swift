// Copyright © 2026 Anton Novoselov. All rights reserved.

import AppGroup
import SwiftUI

/// Automatic extraction of reminders and calendar events from saved notes.
///
/// The two switches are independent: the reminder switch gates the automatic
/// background pass after a note is saved, while the calendar switch decides
/// whether any extraction pass - automatic or run by hand from a note - also
/// looks for dated events.
struct RemindersCalendarSettingsView: View {
    @AppStorage(UserDefaultsStorage.Keys.isAutoReminderExtractionEnabled, store: UserDefaultsStorage.appPrivate)
    private var isAutoReminderExtractionEnabled = false

    @AppStorage(UserDefaultsStorage.Keys.isCalendarEventExtractionEnabled, store: UserDefaultsStorage.appPrivate)
    private var isCalendarEventExtractionEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $isAutoReminderExtractionEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extract Reminder Suggestions Automatically")
                            .font(.body)
                        Text("After saving a new note, detect reminder-worthy tasks in the background and keep them ready for review.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isAutoReminderExtractionEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }
            } header: {
                Text("Reminders")
            }

            Section {
                Toggle(isOn: $isCalendarEventExtractionEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extract Calendar Events Too")
                            .font(.body)
                        Text("Also look for things that happen at a set time - a dinner, a meeting, an appointment - and offer them as calendar events.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: isCalendarEventExtractionEnabled) { _, _ in
                    HapticManager.selectionChanged()
                }
            } header: {
                Text("Calendar")
            } footer: {
                Text("Applies to extraction you start from a note as well as the automatic pass above.")
            }
        }
        .navigationTitle("Reminders and Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RemindersCalendarSettingsView()
    }
}
#endif
