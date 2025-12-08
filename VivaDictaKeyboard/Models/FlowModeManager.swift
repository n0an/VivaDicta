//
//  FlowModeManager.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.19
//

import Foundation
import os

@Observable
final class FlowModeManager {
    private let logger = Logger(category: .flowModeManager)
    private let userDefaults = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)!

    // MARK: - Properties
    public private(set) var availableFlowModes: [FlowMode] = []
    public var selectedFlowMode: FlowMode = FlowMode.defaultMode {
        didSet {
            if oldValue.id != selectedFlowMode.id {
                saveSelectedMode()
                // Notify the main app about the change
                AppGroupCoordinator.shared.setSelectedFlowMode(selectedFlowMode.name)
            }
        }
    }

    // MARK: - Init
    init() {
        loadFlowModes()
        loadSelectedMode()
    }

    // MARK: - Public Methods
    public func refreshFlowModes() {
        loadFlowModes()
        loadSelectedMode()
    }

    // MARK: - Private Methods
    private func loadFlowModes() {
        logger.logInfo("🎯 Loading flow modes from shared storage...")

        if let savedFlowModesData = userDefaults.data(forKey: AppGroupCoordinator.flowModesKey) {
            logger.logInfo("🎯 Found saved modes data, attempting to decode...")

            do {
                let savedFlowModes = try JSONDecoder().decode([FlowMode].self, from: savedFlowModesData)
                availableFlowModes = savedFlowModes
                logger.logInfo("🎯 Successfully loaded \(savedFlowModes.count) flow modes: \(savedFlowModes.map { $0.name }.joined(separator: ", "))")
            } catch {
                logger.logError("🎯 Failed to decode flow modes: \(error.localizedDescription)")
                availableFlowModes = [FlowMode.defaultMode]
            }
        } else {
            logger.logWarning("🎯 No saved flow modes found in shared storage")
            availableFlowModes = [FlowMode.defaultMode]
        }
    }

    private func loadSelectedMode() {
        let selectedFlowModeName = userDefaults.string(forKey: AppGroupCoordinator.selectedFlowModeKey) ?? FlowMode.defaultMode.name
        selectedFlowMode = availableFlowModes.first(where: { $0.name == selectedFlowModeName }) ?? FlowMode.defaultMode
        logger.logInfo("🎯 Loaded selected mode: \(selectedFlowMode.name)")
    }

    private func saveSelectedMode() {
        userDefaults.set(selectedFlowMode.name, forKey: AppGroupCoordinator.selectedFlowModeKey)
        userDefaults.synchronize() // Force immediate write
        logger.logInfo("🎯 Saved selected mode: \(selectedFlowMode.name)")
    }
}
