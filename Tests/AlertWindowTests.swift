import XCTest
import EventKit
import AppKit
@testable import Klaxon

final class AlertWindowTests: XCTestCase {
    var mockEvent: EKEvent!
    var eventStore: EKEventStore!

    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
        mockEvent = EKEvent(eventStore: eventStore)
        mockEvent.title = "Test Meeting"
        mockEvent.startDate = Date()
        mockEvent.endDate = Date().addingTimeInterval(3600)
    }

    override func tearDown() {
        mockEvent = nil
        eventStore = nil
        super.tearDown()
    }

    @MainActor
    func testAlertWindowControllerCanBeCreated() {
        let controller = AlertWindowController(event: mockEvent)

        XCTAssertNotNil(controller, "AlertWindowController should be created")
        XCTAssertNotNil(controller.window, "Window should be created")
    }

    @MainActor
    func testAlertWindowHasCorrectLevel() {
        let controller = AlertWindowController(event: mockEvent)

        XCTAssertEqual(
            controller.window?.level,
            .screenSaver,
            "Window level should be screenSaver to appear above all other windows"
        )
    }

    @MainActor
    func testAlertWindowHasCorrectCollectionBehavior() {
        let controller = AlertWindowController(event: mockEvent)

        let behavior = controller.window?.collectionBehavior ?? []

        XCTAssertTrue(
            behavior.contains(.canJoinAllSpaces),
            "Window should be able to join all spaces"
        )
        XCTAssertTrue(
            behavior.contains(.fullScreenAuxiliary),
            "Window should work with full screen apps"
        )
    }

    @MainActor
    func testAlertWindowHasCorrectSize() {
        let controller = AlertWindowController(event: mockEvent)

        let frame = controller.window?.frame ?? .zero

        // Width should be exactly 500
        XCTAssertEqual(frame.width, 500, "Window width should be 500")
        // Height includes title bar, so it will be greater than content height of 220
        XCTAssertGreaterThanOrEqual(frame.height, 220, "Window height should be at least 220")
    }

    @MainActor
    func testAlertWindowContainsDismissButton() {
        let controller = AlertWindowController(event: mockEvent)

        let contentView = controller.window?.contentView
        let dismissButton = findButton(in: contentView, withTitle: "Dismiss")

        XCTAssertNotNil(dismissButton, "Window should contain a Dismiss button")
        XCTAssertEqual(dismissButton?.keyEquivalent, "\u{1b}", "Dismiss button should respond to Escape key")
    }

    @MainActor
    func testAlertWindowContainsOpenEventButton() {
        let controller = AlertWindowController(event: mockEvent)

        let contentView = controller.window?.contentView
        let openEventButton = findButton(in: contentView, withTitle: "Open Event")

        XCTAssertNotNil(openEventButton, "Window should contain an Open Event button")
        XCTAssertEqual(openEventButton?.keyEquivalent, "\r", "Open Event button should respond to Enter key")
    }

    @MainActor
    func testAlertWindowDisplaysEventTitle() {
        let controller = AlertWindowController(event: mockEvent)

        let contentView = controller.window?.contentView
        let titleLabel = findLabel(in: contentView, withText: "Test Meeting")

        XCTAssertNotNil(titleLabel, "Window should display the event title")
    }

    @MainActor
    func testAlertWindowCanBeShown() {
        let controller = AlertWindowController(event: mockEvent)

        // This test verifies the window can be shown without crashing
        controller.showWindow(nil)

        XCTAssertTrue(
            controller.window?.isVisible ?? false,
            "Window should be visible after showWindow"
        )

        controller.close()
    }

    @MainActor
    func testAlertWindowCanBeClosed() {
        let controller = AlertWindowController(event: mockEvent)
        controller.showWindow(nil)

        controller.close()

        XCTAssertFalse(
            controller.window?.isVisible ?? true,
            "Window should not be visible after close"
        )
    }

    @MainActor
    func testAlertWindowWithUntitledEvent() {
        let untitledEvent = EKEvent(eventStore: eventStore)
        // Don't set title - it will be nil/empty
        untitledEvent.startDate = Date()
        untitledEvent.endDate = Date().addingTimeInterval(3600)

        let controller = AlertWindowController(event: untitledEvent)

        let contentView = controller.window?.contentView
        // Look for the "Untitled Event" fallback text
        let titleLabel = findLabel(in: contentView, withText: "Untitled Event")

        XCTAssertNotNil(titleLabel, "Window should display 'Untitled Event' for events without title")
    }

    @MainActor
    func testAlertWindowVisualDisplay() throws {
        // This test displays the modal for visual verification
        let controller = AlertWindowController(event: mockEvent)
        controller.showWindow(nil)

        // Keep the window visible for 3 seconds so you can see it
        let expectation = expectation(description: "Visual display delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        XCTAssertTrue(controller.window?.isVisible ?? false, "Window should still be visible")
        controller.close()
    }

    // MARK: - Helper Methods

    private func findButton(in view: NSView?, withTitle title: String) -> NSButton? {
        guard let view = view else { return nil }

        if let button = view as? NSButton, button.title == title {
            return button
        }

        for subview in view.subviews {
            if let found = findButton(in: subview, withTitle: title) {
                return found
            }
        }

        return nil
    }

    private func findLabel(in view: NSView?, withText text: String) -> NSTextField? {
        guard let view = view else { return nil }

        if let label = view as? NSTextField, label.stringValue == text {
            return label
        }

        for subview in view.subviews {
            if let found = findLabel(in: subview, withText: text) {
                return found
            }
        }

        return nil
    }
}
