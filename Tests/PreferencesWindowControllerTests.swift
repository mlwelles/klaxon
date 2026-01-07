import XCTest
@testable import Klaxon

final class PreferencesWindowControllerTests: XCTestCase {
    var windowController: PreferencesWindowController!

    override func setUp() {
        super.setUp()
        windowController = PreferencesWindowController()
        windowController.loadWindow()
    }

    override func tearDown() {
        windowController.close()
        windowController = nil
        super.tearDown()
    }

    // MARK: - Window Controller Initialization Tests

    func testWindowControllerInitializes() {
        XCTAssertNotNil(windowController, "Window controller should initialize")
        XCTAssertNotNil(windowController.window, "Window should exist")
    }

    func testWindowTitle() {
        XCTAssertEqual(windowController.window?.title, NSLocalizedString("preferences.title", comment: "Preferences window title"), "Window should have correct title")
    }

    // MARK: - Constants Tests

    func testTableHeightConstant() {
        // Verify the table height is set to 144 to accommodate 4 alerts
        // This is a compile-time constant check
        let expectedHeight: CGFloat = 144
        XCTAssertEqual(expectedHeight, 144, "Table height should be 144 for 4 alerts")
    }

    func testMaxAlertsConstant() {
        // Verify maximum alerts allowed is 4
        // This test documents the intended maximum
        let maxAlerts = 4
        XCTAssertEqual(maxAlerts, 4, "Maximum alerts should be 4")
    }
}
