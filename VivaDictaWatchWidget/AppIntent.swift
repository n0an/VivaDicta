//
//  AppIntent.swift
//  VivaDictaWatchWidget
//
//  Created by Anton Novoselov on 2026.04.02
//

import AppIntents
import Foundation

struct OpenRecorderIntent: AppIntent {
    static var title: LocalizedStringResource { "Record Voice Note" }
    static var description: IntentDescription { "Open VivaDicta and start recording." }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        // Post Darwin notification to toggle recording in the watch app
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.antonnovoselov.VivaDicta.watch.toggleRecording" as CFString),
            nil, nil, true
        )
        return .result()
    }
}
