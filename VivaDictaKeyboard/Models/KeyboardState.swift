//
//  KeyboardState.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation
import os

enum KeyboardViewState {
    case idle        // Normal keyboard with record button
    case recording   // Recording state with flow picker and controls
    case processing  // Processing/transcribing state
}

@Observable
class KeyboardStateManager {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardState")
    var viewState: KeyboardViewState = .idle
    var selectedFlowMode: FlowMode = FlowMode.defaultMode
    var availableFlowModes: [FlowMode] = []
    var didCancelRecording: Bool = false

    init() {
        loadFlowModes()
        loadSelectedMode()
    }

    // MARK: - Flow Mode Management

    func refreshFlowModes() {
        loadFlowModes()
        loadSelectedMode()
    }

    private func loadFlowModes() {
        logger.info("🎯 Loading flow modes from shared storage...")

        if let savedModesData = UserDefaultsStorage.shared.data(forKey: "AIEnhanceModes") {
            logger.info("🎯 Found saved modes data, attempting to decode...")

            do {
                let savedModes = try JSONDecoder().decode([FlowMode].self, from: savedModesData)
                availableFlowModes = savedModes
                logger.info("🎯 Successfully loaded \(savedModes.count) flow modes: \(savedModes.map { $0.name }.joined(separator: ", "))")
            } catch {
                logger.error("🎯 Failed to decode flow modes: \(error.localizedDescription)")
                availableFlowModes = [FlowMode.defaultMode]
            }
        } else {
            logger.warning("🎯 No saved flow modes found in shared storage")
            availableFlowModes = [FlowMode.defaultMode]
        }
    }

    private func loadSelectedMode() {
        let selectedModeName = UserDefaultsStorage.shared.string(forKey: "selectedAIMode") ?? FlowMode.defaultMode.name
        selectedFlowMode = availableFlowModes.first(where: { $0.name == selectedModeName }) ?? FlowMode.defaultMode
    }

    func selectFlowMode(_ mode: FlowMode) {
        selectedFlowMode = mode
        saveSelectedMode()
    }

    private func saveSelectedMode() {
        UserDefaultsStorage.shared.set(selectedFlowMode.name, forKey: "selectedAIMode")
    }

    // MARK: - State Transitions

    func startRecording() {
        viewState = .recording
    }

    func stopRecording() {
        viewState = .processing
    }

    func cancelRecording() {
        viewState = .idle
    }

    func finishProcessing() {
        viewState = .idle
    }
}