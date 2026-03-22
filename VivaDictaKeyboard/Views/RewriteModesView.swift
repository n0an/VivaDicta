//
//  RewriteModesView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import SwiftUI

/// Displays available VivaModes in the keyboard for text processing.
///
/// Shows a scrollable list of modes. Tapping a mode triggers the text processing
/// pipeline that reads text from the host app, sends it to the main app for AI
/// processing using that mode, and replaces it with the result.
///
/// When the main app session is not active, shows a prompt to open the main app.
struct RewriteModesView: View {
    @Environment(KeyboardDictationState.self) var dictationState

    let onModeSelected: (VivaMode) -> Void
    let onOpenApp: () -> Void
    let onBackspace: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    private var modes: [VivaMode] {
        dictationState.vivaModeManager.availableVivaModes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: V/T segment on left, utility buttons on right
            HStack {
                KeyboardTabSegment(dictationState: dictationState)

                Spacer()

                // Utility buttons: space, return, backspace
                HStack(spacing: 4) {
                    
                    if #available(iOS 26.0, *) {
                        Button {
                            HapticManager.lightImpact()
                            onSpace()
                        } label: {
                            
                            Image(systemName: "space")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 20)
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                        .padding(.trailing, 4)
                    } else {
                        Button {
                            HapticManager.lightImpact()
                            onSpace()
                        } label: {
                            
                            Image(systemName: "space")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 24)
                                .background(.quaternary, in: .capsule(style: .continuous))
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .buttonStyle(.plain)
                    }
                    
                    
                    if #available(iOS 26.0, *) {
                        Button {
                            HapticManager.lightImpact()
                            onNewline()
                        } label: {
                            
                            Image(systemName: "return")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 20)
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                        .padding(.trailing, 4)
                    } else {
                        Button {
                            HapticManager.lightImpact()
                            onNewline()
                        } label: {
                            
                            Image(systemName: "return")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 20)
                                .background(.quaternary, in: .capsule(style: .continuous))
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .buttonStyle(.plain)
                    }
                    
                    
                    if #available(iOS 26.0, *) {
                        Button {
                            HapticManager.lightImpact()
                            onBackspace()
                        } label: {
                            
                            Image(systemName: "delete.backward")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 20)
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.red.opacity(0.3)).interactive())
                        .padding(.trailing, 4)
                    } else {
                        Button {
                            HapticManager.lightImpact()
                            onBackspace()
                        } label: {
                            
                            Image(systemName: "delete.backward")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 24)
                                .background(.quaternary, in: .capsule(style: .continuous))
                                .contentShape(.rect)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .buttonStyle(.plain)
                    }
                    
                    
//                    utilityButton(icon: "space", action: onSpace)
//                    utilityButton(icon: "return", action: onNewline)
//                    utilityButton(icon: "delete.backward", action: onBackspace)
                }
            }
            .debugBorder()
            .padding(.horizontal, 16)
            .debugBorder()
//            .padding(.top, 16)
//            .debugBorder()
//            .padding(.bottom, 8)
//            .debugBorder()

            // Content: modes list or "open app" prompt
            if dictationState.isSessionActive {
                modesListView
            } else {
                openAppPromptView
            }
        }
    }

    // MARK: - Modes List

    private var modesListView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(modes) { mode in
                    Button {
                        HapticManager.mediumImpact()
                        onModeSelected(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Open App Prompt

    private var openAppPromptView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Open VivaDicta")
                .font(.system(size: 18, weight: .semibold))

            Text("Launch the app to use AI text processing")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.mediumImpact()
                onOpenApp()
            } label: {
                Label("Open VivaDicta", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Utility Button

//    private func utilityButton(icon: String, action: @escaping () -> Void) -> some View {
//        
//        if #available(iOS 26.0, *) {
//            Button {
//                HapticManager.lightImpact()
//                action()
//            } label: {
//                
//                Image(systemName: icon)
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundStyle(.primary)
//                    .frame(width: 40, height: 24)
//                    .background(.quaternary, in: .capsule(style: .continuous))
//                    .contentShape(.rect)
//            }
//            .padding(.vertical, 8)
//            .padding(.horizontal, 16)
//            .buttonStyle(.plain)
//            .glassEffect(.regular.tint(.gray.opacity(0.3)).interactive())
//        } else {
//            Button {
//                HapticManager.lightImpact()
//                action()
//            } label: {
//                
//                Image(systemName: icon)
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundStyle(.primary)
//                    .frame(width: 40, height: 24)
//                    .background(.quaternary, in: .capsule(style: .continuous))
//                    .contentShape(.rect)
//            }
//            .padding(.vertical, 8)
//            .padding(.horizontal, 16)
//            .buttonStyle(.plain)
//        }
//        
//        
//        
////        Button {
////            HapticManager.lightImpact()
////            action()
////        } label: {
////            Image(systemName: icon)
////                .font(.system(size: 16, weight: .medium))
////                .foregroundStyle(.primary)
////                .frame(width: 36, height: 36)
////                .background(.quaternary, in: .rect(cornerRadius: 8))
////                .contentShape(.rect)
////        }
////        .buttonStyle(.plain)
//    }
}
