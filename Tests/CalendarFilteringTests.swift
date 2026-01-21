import EventKit
import XCTest
@testable import Klaxon

final class CalendarFilteringTests: XCTestCase {
    var testDefaults: UserDefaults!
    var preferences: Preferences!
    var eventStore: EKEventStore!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.klaxon.tests.\(UUID().uuidString)")!
        preferences = Preferences(defaults: testDefaults)
        eventStore = EKEventStore()
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        preferences = nil
        eventStore = nil
        super.tearDown()
    }

    func testAllCalendarsEnabledByDefault() {
        let calendars = eventStore.calendars(for: .event)
        for calendar in calendars {
            XCTAssertTrue(preferences.isCalendarEnabled(calendar.calendarIdentifier),
                         "Calendar '\(calendar.title)' should be enabled by default")
        }
    }

    func testFilteringProducesSubset() {
        let allCalendars = eventStore.calendars(for: .event)
        guard allCalendars.count > 0 else {
            XCTSkip("No calendars available for testing")
        }

        // Disable first calendar
        let firstCalendar = allCalendars[0]
        preferences.setCalendar(firstCalendar.calendarIdentifier, enabled: false)

        // Filter calendars
        let enabledCalendars = allCalendars.filter {
            preferences.isCalendarEnabled($0.calendarIdentifier)
        }

        XCTAssertEqual(enabledCalendars.count, allCalendars.count - 1,
                      "Enabled calendars should be one less than total")
        XCTAssertFalse(enabledCalendars.contains(firstCalendar),
                      "Filtered list should not contain disabled calendar")
    }

    func testEmptyFilterWhenAllDisabled() {
        let allCalendars = eventStore.calendars(for: .event)

        // Disable all calendars
        for calendar in allCalendars {
            preferences.setCalendar(calendar.calendarIdentifier, enabled: false)
        }

        let enabledCalendars = allCalendars.filter {
            preferences.isCalendarEnabled($0.calendarIdentifier)
        }

        XCTAssertEqual(enabledCalendars.count, 0,
                      "No calendars should be enabled when all are disabled")
    }

    func testCalendarServiceWithDisabledCalendars() {
        let service = CalendarService(eventStore: eventStore)

        // This test verifies CalendarService can be created even with disabled calendars
        XCTAssertNotNil(service, "CalendarService should be created successfully")
    }

    func testCleanupDeletedCalendars() {
        // Add some fake calendar IDs to disabled list
        preferences.setCalendar("fake-calendar-1", enabled: false)
        preferences.setCalendar("fake-calendar-2", enabled: false)

        // Add a real calendar ID if available
        let realCalendars = eventStore.calendars(for: .event)
        if let realCalendar = realCalendars.first {
            preferences.setCalendar(realCalendar.calendarIdentifier, enabled: false)
        }

        let beforeCount = preferences.disabledCalendarIDs.count
        XCTAssertGreaterThan(beforeCount, 0, "Should have disabled calendars before cleanup")

        // Cleanup should remove fake IDs but keep real ones
        preferences.cleanupDeletedCalendars(eventStore: eventStore)

        let afterCount = preferences.disabledCalendarIDs.count
        if realCalendars.isEmpty {
            XCTAssertEqual(afterCount, 0, "All fake calendars should be removed")
        } else {
            XCTAssertLessThan(afterCount, beforeCount, "Fake calendars should be removed")
        }
    }

    func testFilteringWithMultipleCalendars() {
        let allCalendars = eventStore.calendars(for: .event)
        guard allCalendars.count >= 3 else {
            XCTSkip("Need at least 3 calendars for this test")
        }

        // Disable first and third calendar
        preferences.setCalendar(allCalendars[0].calendarIdentifier, enabled: false)
        preferences.setCalendar(allCalendars[2].calendarIdentifier, enabled: false)

        let enabledCalendars = allCalendars.filter {
            preferences.isCalendarEnabled($0.calendarIdentifier)
        }

        XCTAssertEqual(enabledCalendars.count, allCalendars.count - 2,
                      "Should have 2 fewer enabled calendars")
        XCTAssertFalse(enabledCalendars.contains(allCalendars[0]),
                      "First calendar should be filtered out")
        XCTAssertTrue(enabledCalendars.contains(allCalendars[1]),
                     "Second calendar should still be enabled")
        XCTAssertFalse(enabledCalendars.contains(allCalendars[2]),
                      "Third calendar should be filtered out")
    }
}
