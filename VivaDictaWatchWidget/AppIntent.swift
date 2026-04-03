//
//  AppIntent.swift
//  VivaDictaWatchWidget
//
//  Created by Anton Novoselov on 2026.04.02
//

import AppIntents

struct OpenRecorderIntent: AppIntent {
    static var title: LocalizedStringResource { "Record Voice Note" }
    static var description: IntentDescription { "Open VivaDicta and start recording." }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "shouldStartRecording")
        return .result()
    }
}
