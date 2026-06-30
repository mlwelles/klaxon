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

    // MARK: - Silence Tests

    func testOccurrenceKeyEquality() {
        let start = Date()
        let a = OccurrenceKey(identifier: "e", startDate: start)
        let b = OccurrenceKey(identifier: "e", startDate: start)
        let c = OccurrenceKey(identifier: "e", startDate: start.addingTimeInterval(60))

        XCTAssertEqual(a, b, "Same identifier and start should be equal")
        XCTAssertNotEqual(a, c, "Different starts should not be equal")
    }

    // MARK: - OccurrenceKey Tests

    func testOccurrenceKeyIgnoresSubSecondDrift() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000.0)
        let drifted = Date(timeIntervalSinceReferenceDate: 1_000_000.4)
        let a = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: base)
        let b = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: drifted)
        XCTAssertEqual(a, b, "Sub-second drift must resolve to the same key")
    }

    func testOccurrenceKeyDistinguishesDifferentMinutes() {
        let t1 = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let t2 = t1.addingTimeInterval(60)
        let a = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: t1)
        let b = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: t2)
        XCTAssertNotEqual(a, b, "Occurrences a minute apart must differ")
    }

    func testOccurrenceKeyPrefersEventIdentifier() {
        let key = OccurrenceKey(eventIdentifier: "evt", externalIdentifier: "ext", title: "T", startDate: Date())
        XCTAssertEqual(key.identifier, "evt")
    }

    func testOccurrenceKeyFallsBackToExternalIdentifier() {
        let key = OccurrenceKey(eventIdentifier: nil, externalIdentifier: "ext-1", title: "T", startDate: Date())
        XCTAssertEqual(key.identifier, "ext-1", "Nil eventIdentifier falls back to externalIdentifier")
    }

    func testOccurrenceKeyFallsBackToTitle() {
        let key = OccurrenceKey(eventIdentifier: nil, externalIdentifier: nil, title: "Standup", startDate: Date())
        XCTAssertEqual(key.identifier, "Standup", "Both identifiers nil falls back to title")
    }

    func testOccurrenceKeyEmptyStringsTreatedAsMissing() {
        let key = OccurrenceKey(eventIdentifier: "", externalIdentifier: "", title: "Standup", startDate: Date())
        XCTAssertEqual(key.identifier, "Standup", "Empty strings are treated as missing")
    }

    // MARK: - Occurrence-aware scan helpers

    private func allHours() -> WorkingHours {
        WorkingHours(enabled: false, startMinutes: 0, endMinutes: 1440, activeDays: [1,2,3,4,5,6,7])
    }
    private func noIgnore() -> TitleIgnoreList { TitleIgnoreList(patterns: []) }

    func testSilenceIsPerOccurrenceViaKey() {
        let service = CalendarService(eventStore: EKEventStore())
        let today = OccurrenceKey(identifier: "standup", startDate: Date())
        let tomorrow = OccurrenceKey(identifier: "standup", startDate: Date().addingTimeInterval(86_400))

        service.silence(key: today)

        XCTAssertTrue(service.isSilenced(today))
        XCTAssertFalse(service.isSilenced(tomorrow), "Same-id next-day occurrence not silenced")
    }

    func testNotifiedStateIsPerOccurrence() {
        let service = CalendarService(eventStore: EKEventStore())
        let a = OccurrenceKey(identifier: "standup", startDate: Date())
        let b = OccurrenceKey(identifier: "standup", startDate: Date().addingTimeInterval(86_400))

        service.recordAlert(.eventStarting, for: a)

        XCTAssertTrue(service.wasAlertSent(.eventStarting, for: a))
        XCTAssertFalse(service.wasAlertSent(.eventStarting, for: b), "Occurrence B independent")
    }

    func testShouldEvaluateSkipsAllDay() {
        let service = CalendarService(eventStore: EKEventStore())
        let key = OccurrenceKey(identifier: "holiday", startDate: Date())
        XCTAssertFalse(service.shouldEvaluate(isAllDay: true, title: "Holiday", eventStart: Date(),
                                              key: key, workingHours: allHours(), ignoreList: noIgnore()))
    }

    func testShouldEvaluateSkipsIgnoredTitle() {
        let service = CalendarService(eventStore: EKEventStore())
        let key = OccurrenceKey(identifier: "ooto", startDate: Date())
        let ignore = TitleIgnoreList(patterns: ["OOTO"])
        XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "OOTO - dentist", eventStart: Date(),
                                              key: key, workingHours: allHours(), ignoreList: ignore))
    }

    func testShouldEvaluateSkipsOutOfWorkingHours() {
        let service = CalendarService(eventStore: EKEventStore())
        let key = OccurrenceKey(identifier: "mtg", startDate: Date())
        let none = WorkingHours(enabled: true, startMinutes: 0, endMinutes: 1440, activeDays: [])
        XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "Mtg", eventStart: Date(),
                                              key: key, workingHours: none, ignoreList: noIgnore()))
    }

    func testShouldEvaluateSkipsSilenced() {
        let service = CalendarService(eventStore: EKEventStore())
        let key = OccurrenceKey(identifier: "mtg", startDate: Date())
        service.silence(key: key)
        XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "Mtg", eventStart: Date(),
                                              key: key, workingHours: allHours(), ignoreList: noIgnore()))
    }

    func testShouldEvaluateAllowsEligibleEvent() {
        let service = CalendarService(eventStore: EKEventStore())
        let key = OccurrenceKey(identifier: "mtg", startDate: Date())
        XCTAssertTrue(service.shouldEvaluate(isAllDay: false, title: "Sprint planning", eventStart: Date(),
                                             key: key, workingHours: allHours(), ignoreList: noIgnore()))
    }

    func testPruneRemovesPastNotifiedAndSilenced() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let oldKey = OccurrenceKey(identifier: "old", startDate: now.addingTimeInterval(-7_200))
        service.recordAlert(.eventStarting, for: oldKey)
        service.silence(key: oldKey)

        service.pruneState(referenceDate: now)

        XCTAssertFalse(service.wasAlertSent(.eventStarting, for: oldKey))
        XCTAssertFalse(service.isSilenced(oldKey))
    }

    func testPruneKeepsRecentState() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let recent = OccurrenceKey(identifier: "soon", startDate: now.addingTimeInterval(600))
        service.recordAlert(.eventStarting, for: recent)
        service.pruneState(referenceDate: now)
        XCTAssertTrue(service.wasAlertSent(.eventStarting, for: recent))
    }

    func testSilenceOccurrenceMarksItSilenced() {
        let service = CalendarService(eventStore: EKEventStore())
        let start = Date()

        service.silenceOccurrence(eventIdentifier: "event-1", startDate: start)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "event-1", startDate: start),
            "Occurrence should be silenced after silenceOccurrence"
        )
    }

    func testSilenceIsScopedToSingleOccurrence() {
        let service = CalendarService(eventStore: EKEventStore())
        let today = Date()
        let tomorrow = today.addingTimeInterval(86_400)

        service.silenceOccurrence(eventIdentifier: "standup", startDate: today)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "standup", startDate: today),
            "Today's occurrence should be silenced"
        )
        XCTAssertFalse(
            service.isOccurrenceSilenced(eventIdentifier: "standup", startDate: tomorrow),
            "Tomorrow's occurrence of the same recurring event should NOT be silenced"
        )
    }

    func testPruneRemovesPastOccurrences() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7_200)

        service.silenceOccurrence(eventIdentifier: "old-event", startDate: twoHoursAgo)
        service.pruneSilencedOccurrences(referenceDate: now)

        XCTAssertFalse(
            service.isOccurrenceSilenced(eventIdentifier: "old-event", startDate: twoHoursAgo),
            "Occurrence more than an hour past should be pruned"
        )
    }

    func testPruneKeepsUpcomingOccurrences() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let tenMinutesAway = now.addingTimeInterval(600)

        service.silenceOccurrence(eventIdentifier: "soon-event", startDate: tenMinutesAway)
        service.pruneSilencedOccurrences(referenceDate: now)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "soon-event", startDate: tenMinutesAway),
            "Upcoming silenced occurrence should survive pruning"
        )
    }
}
