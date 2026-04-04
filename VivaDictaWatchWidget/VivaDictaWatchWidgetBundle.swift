//
//  VivaDictaWatchWidgetBundle.swift
//  VivaDictaWatchWidget
//
//  Created by Anton Novoselov on 02.04.2026.
//

import WidgetKit
import SwiftUI

@main
struct VivaDictaWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        VivaDictaWatchWidget()
        if #available(watchOS 26, *) {
            VivaDictaWatchWidgetControl()
        }
    }
}
