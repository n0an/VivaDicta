//
//  FileManager+Directories.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.28
//

import Foundation

extension FileManager {
    enum DirectoryType {
        case models
        case audio
        case parakeetModels

        var folderName: String {
            switch self {
            case .models:
                return "Models"
            case .audio:
                return "Audio"
            case .parakeetModels:
                return "Models/Parakeet"
            }
        }
    }

    static func appDirectory(for type: DirectoryType) -> URL {
        let documentsDirectory = URL.documentsDirectory
        let directory = documentsDirectory.appendingPathComponent(type.folderName)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return directory
    }

    static func createAppDirectories() {
        // Create all necessary directories on app launch
        _ = appDirectory(for: .models)
        _ = appDirectory(for: .audio)
        _ = appDirectory(for: .parakeetModels)
    }
}