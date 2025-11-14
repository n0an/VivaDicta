//
//  SearchFieldToolbarItem.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI

struct SearchFieldToolbarItem: View {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .focused($isSearchFieldFocused)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                            isExpanded = false
                            isSearchFieldFocused = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                        isSearchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.primary)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var searchText = ""
        @State var isExpanded = false

        var body: some View {
            VStack {
                Spacer()
                HStack {
                    SearchFieldToolbarItem(
                        searchText: $searchText,
                        isExpanded: $isExpanded
                    )
                    Spacer()
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
            }
        }
    }

    return PreviewContainer()
}