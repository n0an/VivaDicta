//
//  VivaDictaWatchApp.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI

@main
struct VivaDictaWatchApp: App {
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
                        if viewModel.state == .idle {
                            viewModel.toggleRecording()
                        }
                    }
                }
        }
    }
}
