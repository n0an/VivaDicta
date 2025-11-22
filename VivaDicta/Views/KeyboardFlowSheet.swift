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
//                .padding(.horizontal)
                .padding(.top, 20)
//                .debugBorder()

            Spacer()

            // Swipe back instruction with arrow icon
            VStack(spacing: 20) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text("Swipe back to start using\nVivaDicta dictation")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
            }
//            .debugBorder()

            Spacer()

            // Bottom swipe indicator
            VStack(spacing: 0) {
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
//            .debugBorder()
//            .padding(.bottom, 20)
        }
        .contentShape(.rect)
        .onTapGesture {
            appState.showKeyboardFlowSheet = false
        }
        .ignoresSafeArea()
    }
    
}



#Preview(traits: .transcriptionsMockData) {
    @State @Previewable var appState = AppState()
    MainView(appState: appState)
        .sheet(isPresented: .constant(true)) {
            KeyboardFlowSheet(appState: appState)
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.hidden)
//                .interactiveDismissDisabled(false)
        }
}



//#Preview {
//    @State @Previewable var appState = AppState()
//    
//    
//
//    KeyboardFlowSheet(appState: appState)
//}
