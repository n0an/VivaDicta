//
//  VivaDictaWatchApp.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI

@main
struct VivaDictaWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: WatchRecordViewModel = {
        let connectivityService = WatchConnectivityService()
        let audioRecorder = WatchAudioRecorder()
        return WatchRecordViewModel(
            connectivityService: connectivityService,
            audioRecorder: audioRecorder
        )
    }()

    var body: some Scene {
        WindowGroup {
            WatchRecordView(viewModel: viewModel)
                .onOpenURL { url in
                    if url.scheme == "vivadicta-watch" && url.host == "record" {
                        startRecordingIfIdle()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        checkControlLaunch()
                    }
                }
        }
    }

    private func startRecordingIfIdle() {
        if viewModel.state == .idle {
            viewModel.toggleRecording()
        }
    }

    private func checkControlLaunch() {
        if UserDefaults.standard.bool(forKey: "shouldStartRecording") {
            UserDefaults.standard.set(false, forKey: "shouldStartRecording")
            startRecordingIfIdle()
        }
    }
}
