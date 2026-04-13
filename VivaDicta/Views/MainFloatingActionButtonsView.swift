//
//  MainFloatingActionButtonsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import SwiftUI

struct MainFloatingActionButtonsView: View {
    @Environment(\.isSearching) private var isSearching
    @Environment(\.colorScheme) private var colorScheme

    let sheetTransitions: Namespace.ID
    let onShowChats: () -> Void
    let onStartRecording: () -> Void

    var body: some View {
        ZStack {
            recordButton

            HStack {
                Spacer()
                chatsButton
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .opacity(isSearching ? 0 : 1)
        .allowsHitTesting(!isSearching)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }

    private var recordButton: some View {
        Button("Record", systemImage: "microphone.fill") {
            onStartRecording()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 40))
        .foregroundStyle(colorScheme == .dark ? .white : .black)
        .padding(22)
        .background(recordButtonBackground)
        .matchedTransitionSource(id: "RecordSheetTransition", in: sheetTransitions)
    }

    private var chatsButton: some View {
        Button("Chats", systemImage: "bubble.left.and.bubble.right") {
            onShowChats()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 18))
        .foregroundStyle(.primary)
        .padding(14)
        .background(chatsButtonBackground)
    }

    @ViewBuilder
    private var recordButtonBackground: some View {
        if #available(iOS 26, *) {
            styledRecordButtonBackground
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            styledRecordButtonBackground
        }
    }

    @ViewBuilder
    private var chatsButtonBackground: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Circle()
                .fill(Color(.systemGray6))
        }
    }

    @ViewBuilder
    private var styledRecordButtonBackground: some View {
        if colorScheme == .dark {
            let darkGradient = AnimatedMeshGradient()
                .mask(
                    Circle()
                        .stroke(lineWidth: 26)
                        .blur(radius: 6)
                )
                .blendMode(.lighten)
                .overlay(
                    Circle()
                        .stroke(lineWidth: 3)
                        .fill(Color.white)
                        .blur(radius: 2)
                        .blendMode(.overlay)
                )
                .overlay(
                    Circle()
                        .stroke(lineWidth: 1)
                        .fill(Color.white)
                        .blur(radius: 1)
                        .blendMode(.overlay)
                )

            if #available(iOS 26, *) {
                darkGradient
                    .clipShape(.circle)
            } else {
                darkGradient
                    .background(.black)
                    .clipShape(.circle)
            }
        } else {
            
            
            let darkGradient = AnimatedMeshGradient2()
                .mask(
                    Circle()
                        .stroke(lineWidth: 26)
                        .blur(radius: 6)
                )
                .overlay(
                    Circle()
                        .stroke(lineWidth: 3)
                        .fill(Color.black.opacity(0.7))
                        .blur(radius: 2)
                        .blendMode(.overlay)
                )
                .overlay(
                    Circle()
                        .stroke(lineWidth: 1)
                        .fill(Color.black.opacity(1.0))
                        .blur(radius: 1)
                        .blendMode(.overlay)
                )

            if #available(iOS 26, *) {
                darkGradient
                    .clipShape(.circle)
            } else {
                darkGradient
                    .background(.white)
                    .clipShape(.circle)
            }
            
            
            
            
            
//            AnimatedMeshGradient2()
//                .overlay(
//                    Circle()
//                        .stroke(lineWidth: 1)
//                        .fill(Color.white)
//                        .blur(radius: 1)
//                        .blendMode(.overlay)
//                )
//                .clipShape(.circle)
//                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
        }
    }
}
