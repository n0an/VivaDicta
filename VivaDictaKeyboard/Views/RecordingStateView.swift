//
//  RecordingStateView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import SwiftUI
import KeyboardKit

struct RecordingStateView: View {
    let stateManager: KeyboardStateManager
    let onCancelTapped: () -> Void
    let onStopTapped: () -> Void

    @State private var showFlowModePicker = false

    var body: some View {
        ZStack {
            // Background matching keyboard appearance
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar with Cancel Button
                HStack {
                    Spacer()

                    // Cancel button (X)
                    Button(action: onCancelTapped) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Flow Mode Picker
                VStack(spacing: 20) {
                    Button(action: {
                        showFlowModePicker.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Text(stateManager.selectedFlowMode.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.primary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                    }

                    // Recording indicator dots (placeholder for now)
                    HStack(spacing: 4) {
                        ForEach(0..<12) { index in
                            Circle()
                                .fill(index < 6 ? Color.red.opacity(0.8) : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 20)
                }

                Spacer()

                // Stop Button
                Button(action: onStopTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Stop")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.red)
                    )
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showFlowModePicker) {
            FlowModePickerSheet(
                stateManager: stateManager,
                isPresented: $showFlowModePicker
            )
        }
    }
}

// MARK: - Flow Mode Picker Sheet

struct FlowModePickerSheet: View {
    let stateManager: KeyboardStateManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(stateManager.availableFlowModes, id: \.id) { mode in
                    Button(action: {
                        stateManager.selectFlowMode(mode)
                        isPresented = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.primary)

                                if mode.aiEnhanceEnabled {
                                    Text("AI Enhancement enabled")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }

                            Spacer()

                            if mode.id == stateManager.selectedFlowMode.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Flow Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    RecordingStateView(
        stateManager: KeyboardStateManager(),
        onCancelTapped: {},
        onStopTapped: {}
    )
}