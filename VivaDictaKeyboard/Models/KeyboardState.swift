////
////  KeyboardState.swift
////  VivaDictaKeyboard
////
////  Created by Anton Novoselov on 2025.10.03
////
//
//import Foundation
//import os
//
//enum KeyboardViewState {
//    case idle        // Normal keyboard with record button
//    case recording   // Recording state with flow picker and controls
//    case processing  // Processing/transcribing state
//}
//
//@Observable
//class KeyboardStateManager {
//    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardState")
//    public var viewState: KeyboardViewState = .idle
//    public var processingStage: ProcessingStage = .waitingToStart
//    public private(set) var selectedFlowMode: FlowMode = FlowMode.defaultMode
//    public private(set) var availableFlowModes: [FlowMode] = []
//    public var didCancelRecording: Bool = false
//
//    init() {
//        loadFlowModes()
//        loadSelectedMode()
//    }
//
//    // MARK: - Flow Mode Management
//
//    public func refreshFlowModes() {
//        loadFlowModes()
//        loadSelectedMode()
//    }
//
//    private func loadFlowModes() {
//        logger.logInfo("🎯 Loading flow modes from shared storage...")
//
//        if let savedModesData = UserDefaultsStorage.shared.data(forKey: AppGroupConfig.aiEnhanceModesKey) {
//            logger.logInfo("🎯 Found saved modes data, attempting to decode...")
//
//            do {
//                let savedModes = try JSONDecoder().decode([FlowMode].self, from: savedModesData)
//                availableFlowModes = savedModes
//                logger.logInfo("🎯 Successfully loaded \(savedModes.count) flow modes: \(savedModes.map { $0.name }.joined(separator: ", "))")
//            } catch {
//                logger.logError("🎯 Failed to decode flow modes: \(error.localizedDescription)")
//                availableFlowModes = [FlowMode.defaultMode]
//            }
//        } else {
//            logger.logWarning("🎯 No saved flow modes found in shared storage")
//            availableFlowModes = [FlowMode.defaultMode]
//        }
//    }
//
//    private func loadSelectedMode() {
//        let selectedModeName = UserDefaultsStorage.shared.string(forKey: AppGroupConfig.selectedAIModeKey) ?? FlowMode.defaultMode.name
//        selectedFlowMode = availableFlowModes.first(where: { $0.name == selectedModeName }) ?? FlowMode.defaultMode
//    }
//
//    public func selectFlowMode(_ mode: FlowMode) {
//        selectedFlowMode = mode
//        saveSelectedMode()
//    }
//
//    private func saveSelectedMode() {
//        UserDefaultsStorage.shared.set(selectedFlowMode.name, forKey: AppGroupConfig.selectedAIModeKey)
//    }
//
//    // MARK: - State Transitions
//
//    public func startRecording() {
//        viewState = .recording
//    }
//
//    public func stopRecording() {
//        viewState = .processing
//    }
//
//    public func cancelRecording() {
//        viewState = .idle
//    }
//
//    public func finishProcessing() {
//        viewState = .idle
//    }
//}
