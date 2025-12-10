import XCTest
import EventKit
@testable import Klaxon

final class CalendarAccessTests: XCTestCase {
    var eventStore: EKEventStore!

    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
    }

    override func tearDown() {
        eventStore = nil
        super.tearDown()
    }

    func testCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)

        // Test that we can check the authorization status
        // Valid states depend on macOS version
        let isValidStatus: Bool
        if #available(macOS 14.0, *) {
            isValidStatus = [.notDetermined, .restricted, .denied, .fullAccess, .writeOnly].contains(status)
        } else {
            isValidStatus = [.notDetermined, .restricted, .denied, .authorized].contains(status)
        }

        XCTAssertTrue(
            isValidStatus,
            "Authorization status should be a valid EKAuthorizationStatus value"
        )
    }

    func testEventStoreCanBeCreated() {
        XCTAssertNotNil(eventStore, "EKEventStore should be created successfully")
    }

    func testCanRequestCalendarAccess() {
        let expectation = expectation(description: "Calendar access request completes")

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                // We don't assert on granted since it depends on user permissions
                // We just verify the request completes without crashing
                expectation.fulfill()
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 15.0)
    }

    func testCanAccessCalendarsWhenAuthorized() throws {
        // Wait up to 10 seconds for permission to be granted
        let timeout = Date().addingTimeInterval(10)
        var isAuthorized = false

        while Date() < timeout && !isAuthorized {
            let status = EKEventStore.authorizationStatus(for: .event)
            if #available(macOS 14.0, *) {
                isAuthorized = status == .fullAccess
            } else {
                isAuthorized = status == .authorized
            }

            if !isAuthorized {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        if isAuthorized {
            let calendars = eventStore.calendars(for: .event)
            // If authorized, we should be able to fetch calendars (may be empty)
            XCTAssertNotNil(calendars, "Should be able to fetch calendars when authorized")
        } else {
            // Skip test if not authorized - this is expected in CI environments
            throw XCTSkip("Calendar access not authorized - skipping calendar access test")
        }
    }

    func testCanCreateEventPredicate() {
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 3, to: now)!
        let calendars = eventStore.calendars(for: .event)

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: calendars
        )

        XCTAssertNotNil(predicate, "Should be able to create event predicate")
    }
}
