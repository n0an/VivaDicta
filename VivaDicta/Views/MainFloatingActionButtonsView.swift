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
        .opacity(isSearching ? 0 : 1)
        .allowsHitTesting(!isSearching)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }

    private var recordButton: some View {
        Button {
            onStartRecording()
        }
        label: {
            recordIcon
        }
        .accessibilityLabel("Record")
        .padding(22)
        .background(recordButtonBackground)
        .matchedTransitionSource(id: "RecordSheetTransition", in: sheetTransitions)
    }

    private var recordIcon: some View {
        let icon = Image(systemName: "microphone.fill")
            .font(.system(size: 40))

        return Group {
            if colorScheme == .dark {
                icon
                    .foregroundStyle(.white)
                //                AnimatedMeshGradient2()
//                    .mask { icon }
                    
            } else {
                AnimatedMeshGradient()
                    .mask { icon }
                    .overlay {
                        Color.black.opacity(0.3)
                            .mask { icon }
                    }
            }
        }
        .frame(width: 48, height: 48)
    }

    private var chatsButton: some View {
        Button("Chats", systemImage: "bubble.left.and.text.bubble.right") {
            onShowChats()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.white)
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
            if colorScheme == .dark {
                AnimatedMeshGradient2()
                    .mask {
                        Circle()
                            .strokeBorder(lineWidth: 3)
                            .blur(radius: 1)
                    }
                    .glassEffect(.regular.tint(.blue.opacity(0.35)).interactive(), in: .circle)
            } else {
                AnimatedMeshGradient()
                    .mask {
                        Circle()
                            .strokeBorder(lineWidth: 3)
                    }
                    .glassEffect(.regular.tint(.blue.opacity(0.75)).interactive(), in: .circle)
                    .blur(radius: 1)
            }
        } else {
            Circle()
                .fill(.blue)
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
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
            } else {
                darkGradient
                    .background(.white)
                    .clipShape(.circle)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
            }
        }
    }
}
