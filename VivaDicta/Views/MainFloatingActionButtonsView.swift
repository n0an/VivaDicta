//
//  MainFloatingActionButtonsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import SwiftUI

struct MainFloatingActionButtonsView: View {
    @Environment(\.isSearching) private var isSearching

    let recordButtonBounceTrigger: Int
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
        Button("Record", systemImage: "microphone") {
            onStartRecording()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 24))
        .symbolEffect(.bounce.up.byLayer, options: .repeat(2), value: recordButtonBounceTrigger)
        .foregroundStyle(.white)
        .padding(18)
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
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint(.orange).interactive(), in: .circle)
        } else {
            Circle()
                .fill(.orange)
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
}
