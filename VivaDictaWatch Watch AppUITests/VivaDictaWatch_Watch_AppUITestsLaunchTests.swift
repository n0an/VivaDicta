//
//  VivaDictaWatch_Watch_AppUITestsLaunchTests.swift
//  VivaDictaWatch Watch AppUITests
//
//  Created by Anton Novoselov on 02.04.2026.
//

import XCTest

final class VivaDictaWatch_Watch_AppUITestsLaunchTests: XCTestCase {

    nonisolated override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
