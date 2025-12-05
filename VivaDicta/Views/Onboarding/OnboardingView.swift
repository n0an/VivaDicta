//
//  OnboardingView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        
        VStack(spacing: 0) {
            
            // Navigation Bar
            HStack {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            
            TabView(selection: $currentPage) {
                OnboardingWelcomePage {
                    withAnimation {
                        currentPage = 1
                    }
                }
                .tag(0)

                OnboardingMicrophonePage(
                    onBack: {
                        withAnimation {
                            currentPage = 0
                        }
                    },
                    onContinue: {
                        withAnimation {
                            currentPage = 2
                        }
                    }
                )
                .tag(1)

                OnboardingKeyboardPage(
                    onBack: {
                        withAnimation {
                            currentPage = 1
                        }
                    },
                    onComplete: onComplete
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            
            
            // Button
            OnboardingPrimaryButton(title: "Get Started", action: {})
                .padding(.horizontal, 24)
//                .padding(.bottom, 36)
            
        }
        
        
        
        
        .background(Color(.systemGroupedBackground))
//        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
