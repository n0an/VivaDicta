//
//  KeyboardIllustration.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI


// MARK: - Keyboard Illustration

struct KeyboardIllustration: View {
    
    @State var animate: Bool = false
    
    private let keySpacing: CGFloat = 6
    private let keyHeight: CGFloat = 42
    private let keyWidth: CGFloat = 33

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with MicButton
            HStack {
                Spacer()

                MicButton(
                    fontSize: 34,
                    padding: 6,
                    backgroundColor: .orange.opacity(0.5),
                    borderWidth: 0.5,
                    onTapAction: {}
                )
                .scaleEffect(animate ? 1.5 : 1.0)
                .onAppear {
                    animate = false
                    
                    withAnimation(.spring.delay(1.0)) {
                        
                        animate = true
                        
                        Task { @MainActor in
                            try await Task.sleep(for: .seconds(1.3))
                            withAnimation {
                                animate = false
                            }
                        }
                    }
                    
                    
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Row 1: QWERTYUIOP
            HStack(spacing: keySpacing) {
                ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { key in
                    KeyCap(letter: key, width: keyWidth, height: keyHeight)
                }
            }
            .padding(.bottom, keySpacing)

            // Row 2: ASDFGHJKL
            HStack(spacing: keySpacing) {
                ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { key in
                    KeyCap(letter: key, width: keyWidth, height: keyHeight)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemBackground))
    }
}

struct KeyCap: View {
    @Environment(\.colorScheme) private var colorScheme

    let letter: String
    var width: CGFloat = 32
    var height: CGFloat = 44

    var body: some View {
        Text(letter)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: width, height: height)
            .background(keyBackground, in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 0.5, y: 1)
    }

    private var keyBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground)
    }
}

