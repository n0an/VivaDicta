//
//  CategoryChipsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.23
//

import SwiftUI

struct CategoryChipsView: View {
    static let favoritesFilter = "__favorites__"

    let categories: [String]
    @Binding var selectedCategory: String?
    var showFavorites: Bool = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                if showFavorites {
                    CategoryChip(
                        title: "Favorites",
                        icon: "heart.fill",
                        isSelected: selectedCategory == Self.favoritesFilter
                    ) {
                        selectedCategory = Self.favoritesFilter
                    }
                }
                ForEach(categories, id: \.self) { category in
                    CategoryChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct CategoryChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
