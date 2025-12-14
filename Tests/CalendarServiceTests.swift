import XCTest
import EventKit
@testable import Klaxon

final class CalendarServiceTests: XCTestCase {

    // MARK: - AlertType Tests

    func testAlertTypeWarningEquality() {
        let type1 = AlertType.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let type2 = AlertType.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let type3 = AlertType.warning(minutes: 10, sound: "fire-alarm-bell", soundDuration: 4.0)

        XCTAssertEqual(type1, type2, "Warnings with same values should be equal")
        XCTAssertNotEqual(type1, type3, "Warnings with different minutes should not be equal")
    }

    func testAlertTypeEventStartingEquality() {
        let type1 = AlertType.eventStarting
        let type2 = AlertType.eventStarting

        XCTAssertEqual(type1, type2, "Event starting types should be equal")
    }

    func testAlertTypeWarningNotEqualToEventStarting() {
        let warning = AlertType.warning(minutes: 0, sound: "fire-alarm-bell", soundDuration: 4.0)
        let eventStarting = AlertType.eventStarting

        XCTAssertNotEqual(warning, eventStarting, "Warning should not equal event starting")
    }

    func testAlertTypeIsHashable() {
        var set = Set<AlertType>()

        set.insert(.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0))
        set.insert(.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0)) // Duplicate
        set.insert(.warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0))
        set.insert(.eventStarting)

        XCTAssertEqual(set.count, 3, "Set should contain 3 unique alert types")
    }

    func testAlertTypeCanBeUsedAsDictionaryKey() {
        var dict: [AlertType: String] = [:]

        dict[.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0)] = "first"
        dict[.warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0)] = "second"
        dict[.eventStarting] = "start"

        XCTAssertEqual(dict[.warning(minutes: 5, sound: "fire-alarm-bell", soundDuration: 4.0)], "first")
        XCTAssertEqual(dict[.warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0)], "second")
        XCTAssertEqual(dict[.eventStarting], "start")
    }

    // MARK: - AlertWarning Tests

    func testAlertWarningCreation() {
        let warning = AlertWarning(minutesBefore: 10, sound: "fire-alarm-bell", soundDuration: 4.0)

        XCTAssertEqual(warning.minutesBefore, 10)
        XCTAssertEqual(warning.sound, "fire-alarm-bell")
        XCTAssertEqual(warning.soundDuration, 4.0)
    }

    func testAlertWarningMutability() {
        var warning = AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)

        warning.minutesBefore = 15

        XCTAssertEqual(warning.minutesBefore, 15)
    }

    func testAlertWarningDefaultWarningsAreSorted() {
        let defaults = AlertWarning.defaultWarnings

        // First warning should have more minutes than second
        XCTAssertGreaterThan(defaults[0].minutesBefore, defaults[1].minutesBefore,
                            "Default warnings should be in descending order by minutes")
    }

    func testAlertWarningCanConvertToAlertType() {
        let warning = AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let alertType = AlertType.warning(minutes: warning.minutesBefore, sound: warning.sound, soundDuration: warning.soundDuration)

        if case .warning(let minutes, let sound, let duration) = alertType {
            XCTAssertEqual(minutes, 5)
            XCTAssertEqual(sound, "fire-alarm-bell")
            XCTAssertEqual(duration, 4.0)
        } else {
            XCTFail("Should be a warning type")
        }
    }

    // MARK: - CalendarService Creation Tests

    func testCalendarServiceCanBeCreated() {
        let eventStore = EKEventStore()
        let service = CalendarService(eventStore: eventStore)

        XCTAssertNotNil(service, "CalendarService should be creatable")
    }

    func testCalendarServiceHasOnEventAlertCallback() {
        let eventStore = EKEventStore()
        let service = CalendarService(eventStore: eventStore)

        var callbackCalled = false
        service.onEventAlert = { _, _ in
            callbackCalled = true
        }

        XCTAssertNotNil(service.onEventAlert, "Callback should be settable")
    }

    // MARK: - Integration Tests

    func testMultipleWarningsCanBeConfigured() {
        // Create test defaults
        let testDefaults = UserDefaults(suiteName: "com.klaxon.tests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: testDefaults)

        // Configure multiple warnings
        prefs.warnings = [
            AlertWarning(minutesBefore: 30, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 15, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 1, sound: "fire-alarm-bell", soundDuration: 4.0)
        ]

        XCTAssertEqual(prefs.warnings.count, 4, "Should have 4 configured warnings")

        // Verify each warning
        XCTAssertEqual(prefs.warnings[0].minutesBefore, 30)
        XCTAssertEqual(prefs.warnings[1].minutesBefore, 15)
        XCTAssertEqual(prefs.warnings[2].minutesBefore, 5)
        XCTAssertEqual(prefs.warnings[3].minutesBefore, 1)

        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }

    func testWarningsGenerateUniqueAlertTypes() {
        let warnings = [
            AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 10, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 15, sound: "fire-alarm-bell", soundDuration: 4.0)
        ]

        let alertTypes = warnings.map {
            AlertType.warning(minutes: $0.minutesBefore, sound: $0.sound, soundDuration: $0.soundDuration)
        }

        let uniqueTypes = Set(alertTypes)

        XCTAssertEqual(uniqueTypes.count, 3, "All warnings should generate unique alert types")
    }

    func testEmptyWarningsArrayIsValid() {
        let testDefaults = UserDefaults(suiteName: "com.klaxon.tests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: testDefaults)

        prefs.warnings = []

        XCTAssertEqual(prefs.warnings.count, 0, "Empty warnings array should be valid")

        // Cleanup
        testDefaults.removePersistentDomain(forName: testDefaults.description)
    }
}
