//
//  VivaDictaWidgetControl.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import AppIntents
import SwiftUI
import WidgetKit

struct RecordingControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Recording Control"
    static let description = IntentDescription("Configure the recording control.")

    @Parameter(title: "Recording Name", default: "Recording")
    var recordingName: String
}

struct RecordingControlValueProvider: AppIntentControlValueProvider {
    func previewValue(configuration: RecordingControlConfiguration) -> Bool {
        false
    }

    func currentValue(configuration: RecordingControlConfiguration) async throws -> Bool {
        let coordinator = AppGroupCoordinator.shared
        return coordinator.isRecording
    }
}

struct VivaDictaWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {

        AppIntentControlConfiguration(
            kind: "VivaDictaControlWidget",
            provider: RecordingControlValueProvider()
        ) { isRecording in
            ControlWidgetToggle(
                "Recording in VivaDicta",
                isOn: isRecording,
                action: ToggleRecordIntent()
            ) { isTurnedOn in
                Label("Toggle Recording", systemImage: "microphone.circle")
            }
        }
        .displayName("Toggle Recording")
        .description("Toggle recording in VivaDicta")
    }
}
