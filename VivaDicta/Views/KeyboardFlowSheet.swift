//
//  KeyboardFlowSheet.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.21
//

import SwiftUI

struct KeyboardFlowSheet: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Flow Activated")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
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
            }
            
            Spacer()
            
            VStack(spacing: 0) {
                Text("Swipe right from here")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Capsule()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 134, height: 5)
                    .padding(.top, 8)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            appState.showKeyboardFlowSheet = false
        }
        .ignoresSafeArea()
    }
}

#Preview(traits: .transcriptionsMockData) {
    
    @Previewable @State var appState = AppState()
    MainView()
        .environment(appState)
        .environment(Router())
        .sheet(isPresented: .constant(true)) {
            KeyboardFlowSheet()
                .environment(appState)
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.hidden)
        }
}

