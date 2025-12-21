//
//  VivaModeManager.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.19
//

import Foundation
import os

@Observable
final class VivaModeManager {
    private let logger = Logger(category: .vivaModeManager)
    private let userDefaults = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)!

    // MARK: - Properties
    public private(set) var availableVivaModes: [VivaMode] = []
    public var selectedVivaMode: VivaMode = VivaMode.defaultMode {
        didSet {
            if oldValue.id != selectedVivaMode.id {
                saveSelectedMode()
                // Notify the main app about the change
                AppGroupCoordinator.shared.setSelectedVivaMode(selectedVivaMode.name)
            }
        }
    }

    // MARK: - Init
    init() {
        loadVivaModes()
        loadSelectedMode()
    }

    // MARK: - Public Methods
    public func refreshVivaModes() {
        loadVivaModes()
        loadSelectedMode()
    }

    // MARK: - Private Methods
    private func loadVivaModes() {
        logger.logInfo("🎯 Loading viva modes from shared storage...")

        if let savedVivaModesData = userDefaults.data(forKey: AppGroupCoordinator.vivaModesKey) {
            logger.logInfo("🎯 Found saved modes data, attempting to decode...")

            do {
                let savedVivaModes = try JSONDecoder().decode([VivaMode].self, from: savedVivaModesData)
                availableVivaModes = savedVivaModes
                logger.logInfo("🎯 Successfully loaded \(savedVivaModes.count) viva modes: \(savedVivaModes.map { $0.name }.joined(separator: ", "))")
            } catch {
                logger.logError("🎯 Failed to decode viva modes: \(error.localizedDescription)")
                availableVivaModes = [VivaMode.defaultMode]
            }
        } else {
            logger.logWarning("🎯 No saved viva modes found in shared storage")
            availableVivaModes = [VivaMode.defaultMode]
        }
    }

    private func loadSelectedMode() {
        let selectedVivaModeName = userDefaults.string(forKey: AppGroupCoordinator.selectedVivaModeKey) ?? VivaMode.defaultMode.name
        selectedVivaMode = availableVivaModes.first(where: { $0.name == selectedVivaModeName }) ?? VivaMode.defaultMode
        logger.logInfo("🎯 Loaded selected mode: \(selectedVivaMode.name)")
    }

    private func saveSelectedMode() {
        userDefaults.set(selectedVivaMode.name, forKey: AppGroupCoordinator.selectedVivaModeKey)
        userDefaults.synchronize() // Force immediate write
        logger.logInfo("🎯 Saved selected mode: \(selectedVivaMode.name)")
    }
}
