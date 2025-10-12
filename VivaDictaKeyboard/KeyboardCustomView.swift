//
//  KeyboardCustomView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.05
//

import SwiftUI
import KeyboardKit

//struct KeyboardCustomView: View {
//    let controller: KeyboardInputViewController
//    let stateManager: KeyboardStateManager?
//    let appStateViewModel: AppStateViewModel?
//
//    let onCancelRecording: () -> Void
//    let onStopRecording: () -> Void
//    let onCancelProcessing: () -> Void
//    let onRecordTapped: () -> Void
//
//    var body: some View {
//        Group {
//            if let stateManager, let appStateViewModel {
//                switch stateManager.viewState {
//                case .recording:
//                    RecordingStateView(
//                        stateManager: stateManager,
//                        onCancelTapped: onCancelRecording,
//                        onStopTapped: onStopRecording
//                    )
//
//                case .processing:
//                    ProcessingStateView(
//                        processingStage: .init(
//                            get: { stateManager.processingStage },
//                            set: { stateManager.processingStage = $0 }
//                        ),
//                        onCancel: onCancelProcessing
//                    )
//
//                case .idle:
//                    VStack(spacing: 0) {
//                        KeyboardView(
//                            state: controller.state,
//                            services: controller.services,
//                            buttonContent: { $0.view },
//                            buttonView: { $0.view },
//                            collapsedView: { $0.view },
//                            emojiKeyboard: { $0.view },
//                            toolbar: { _ in
//                                RecordingToolbar(
//                                    isMainAppActive: appStateViewModel.isMainAppActive,
//                                    isRecording: appStateViewModel.isRecording,
//                                    onRecordTapped: onRecordTapped
//                                )
//                            }
//                        )
//                    }
//                }
//            } else {
//                EmptyView()
//            }
//            
//        }
//    }
//}
