//
//  VivaDictaWidgetControl.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import AppIntents
import SwiftUI
import WidgetKit

struct VivaDictaWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        
        StaticControlConfiguration(kind: "VivaDictaControlWidget") {
            
            ControlWidgetButton(action: ToggleRecordIntent()) {
                Image(systemName: "microphone.circle")
            }
        }
        
        
        .displayName("Toggle Record")
        .description("Toggle Record in VivaDicta")
    }
}





/// An App Intent that generates a developer horoscope based on a GitHub username.
///
/// This intent is used to trigger horoscope generation through system integrations
/// such as Siri, Shortcuts, or Spotlight. It calls `HoroscopeService` to fetch
/// the result and returns a `HoroscopeView` to display it.
///
/// - Parameters:
///   - username: The GitHub username used to generate a personalized horoscope.
/// - Returns: A rendered `HoroscopeView` inside a system snippet UI.
//struct HoroscopeIntent: AppIntent {
//    static var parameterSummary: some ParameterSummary {
//        Summary("Generate a horoscope for \(\.$username)")
//    }
//
//    static var title: LocalizedStringResource = "Horoscope"
//    static var description = IntentDescription("Generates a horoscope")
//
//    @Parameter(title: "Github username")
//    var username: String
//
//    @Dependency
//    private var horoscopeService: HoroscopeService
//
//    func perform() async throws -> some IntentResult & ShowsSnippetView {
//        let horoscope = try await horoscopeService.horoscope(username: username)
//        return .result(view: HoroscopeView(horoscope: horoscope))
//    }
//}












struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
