//
//  VivaDictaWidgetBundle.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 02.10.2025.
//

import WidgetKit
import SwiftUI

@main
struct VivaDictaWidgetBundle: WidgetBundle {
    var body: some Widget {
        VivaDictaWidget()
        VivaDictaWidgetControl()
        VivaDictaLiveActivity()
    }
}
