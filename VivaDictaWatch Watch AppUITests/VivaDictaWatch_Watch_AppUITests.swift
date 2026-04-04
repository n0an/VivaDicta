//
//  VivaDictaWatch_Watch_AppUITests.swift
//  VivaDictaWatch Watch AppUITests
//
//  Created by Anton Novoselov on 02.04.2026.
//

import XCTest

final class VivaDictaWatch_Watch_AppUITests: XCTestCase {

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    nonisolated override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
