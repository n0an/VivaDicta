//
//  Persistence.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.03
//

import SwiftData
import Foundation

struct Persistence {
    static var container1: ModelContainer {
        let container: ModelContainer = {
            let sharedStoreURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupCoordinator.shared.appGroupId)!.appendingPathComponent("VivaDicta.sqlite")
            let config = ModelConfiguration(url: sharedStoreURL)
            return try! ModelContainer(for: Transcription.self, configurations: config)
        }()

        return container
    }

//    static var latestTranscription: Transcription? {
//        let context = ModelContext(Persistence.container)
//
//        let predicate = #Predicate<Transcription> { CLAUSE HERE }
//        let descriptor = FetchDescriptor(predicate: predicate)
//
//        return try? context.fetch(descriptor).first
//    }
}
