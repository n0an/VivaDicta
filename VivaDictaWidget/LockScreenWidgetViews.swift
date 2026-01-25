//
//  LockScreenWidgetViews.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2026.01.25
//

import SwiftUI
import WidgetKit

struct LockScreenCircularView: View {
    var body: some View {
        VStack {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange.gradient)
                .font(.system(size: 40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                     startPoint: .bottom, endPoint: .top))
        }
        .containerBackground(for: .widget) { }
    }
}

struct LockScreenIconCircularView: View {
    var body: some View {
        VStack {
            Image("VivaDictaIconFrameless")
                .resizable()
                .scaledToFit()
                .frame(width: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            ContainerRelativeShape()
                .fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                     startPoint: .bottom, endPoint: .top))
        }
        .containerBackground(for: .widget) { }
    }
}



struct LockScreenRectangularView: View {
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mic.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange.gradient)
                    .font(.system(size: 40))

                Text("VivaDicta")
            }
        }
        .containerBackground(for: .widget) { }
    }
}

struct LockScreenIconRectangularView: View {
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Image("VivaDictaIconFrameless")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30)

                Text("VivaDicta")
            }
        }
        .containerBackground(for: .widget) { }
    }
}
