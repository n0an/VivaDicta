//
//  KeyboardFlowSheet.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.21
//

import SwiftUI

struct KeyboardFlowSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
//            Capsule()
//                .fill(Color.secondary.opacity(0.5))
//                .frame(width: 40, height: 5)
//                .padding(.top, 8)
//                .padding(.bottom, 20)

            // Title
            Text("Keyboard Flow Activated")
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top, 40)

            Spacer()

            // Swipe back instruction with arrow icon
            VStack(spacing: 20) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Swipe back to start using\nVivaDicta dictation")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Bottom swipe indicator
            VStack(spacing: 8) {
                Text("Swipe right from here")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
//                Spacer()
                
                Capsule()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 134, height: 5)
                    .padding(.top, 8)
//                    .padding(.bottom, 20)
                
                //                Capsule()
                //                    .background(.blue)
//                    .frame(height: 6)
//                    .frame(maxWidth: 100)

//                ProgressView(value: 0.3)
//                    .tint(.blue)
//                    .scaleEffect(y: 1.5)
//                    .frame(maxWidth: 200)
            }
//            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Auto-dismiss after a delay if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//                appState.showKeyboardFlowSheet = false
            }
        }
    }
}

#Preview {
    @State @Previewable var appState = AppState()

    KeyboardFlowSheet(appState: appState)
}
