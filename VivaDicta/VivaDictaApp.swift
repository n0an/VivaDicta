//
//  VivaDictaApp.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 02.08.2025.
//

import SwiftUI
import SwiftData

@main
struct VivaDictaApp: App {
    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
        .modelContainer(for: Transcription.self)
    }
}
