//
//  VivaDictaApp.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI
import SwiftData

@main
struct VivaDictaApp: App {
    init() {
        // Initialize app directories
        FileManager.createAppDirectories()
    }

    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
        .modelContainer(for: Transcription.self)
    }
}
