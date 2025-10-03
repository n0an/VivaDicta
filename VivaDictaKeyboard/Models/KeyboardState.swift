//
//  KeyboardState.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import Foundation

enum KeyboardViewState {
    case idle        // Normal keyboard with record button
    case recording   // Recording state with flow picker and controls
    case processing  // Processing/transcribing state
}

@Observable
class KeyboardStateManager {
    var viewState: KeyboardViewState = .idle
    var selectedFlowMode: FlowMode = FlowMode.defaultMode
    var availableFlowModes: [FlowMode] = []
    var didCancelRecording: Bool = false

    init() {
        loadFlowModes()
        loadSelectedMode()
    }

    // MARK: - Flow Mode Management

    private func loadFlowModes() {
        if let savedModesData = UserDefaultsStorage.shared.data(forKey: "AIEnhanceModes"),
           let savedModes = try? JSONDecoder().decode([FlowMode].self, from: savedModesData) {
            availableFlowModes = savedModes
        } else {
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