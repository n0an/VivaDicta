//
//  Extensions.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 02.08.2025.
//

import SwiftUI

struct BlurTransition: Transition {
    var radius: CGFloat
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
    }
}

extension Transition where Self == BlurTransition {
    static func blur(radius: CGFloat) -> Self {
        BlurTransition(radius: radius)
    }
}
