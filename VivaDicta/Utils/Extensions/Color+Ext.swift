//
//  Color+Ext.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.22
//

import SwiftUI

extension Color {
    static func random() -> Color {
        Color(
            red: Double.random(in: 0 ... 1),
            green: Double.random(in: 0 ... 1),
            blue: Double.random(in: 0 ... 1)
        )
    }

    var sui: Color { Color(self) }
}
