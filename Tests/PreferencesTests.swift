import AVFoundation
import XCTest
@testable import Klaxon

final class PreferencesTests: XCTestCase {
    var testDefaults: UserDefaults!
    var preferences: Preferences!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.klaxon.tests.\(UUID().uuidString)")!
        preferences = Preferences(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        preferences = nil
        super.tearDown()
    }

    // MARK: - AlertWarning Model Tests

    func testAlertWarningEquality() {
        let warning1 = AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let warning2 = AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let warning3 = AlertWarning(minutesBefore: 10, sound: "fire-alarm-bell", soundDuration: 4.0)

        XCTAssertEqual(warning1, warning2, "Warnings with same values should be equal")
        XCTAssertNotEqual(warning1, warning3, "Warnings with different values should not be equal")
    }

    func testAlertWarningCodable() throws {
        let warning = AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)
        let encoded = try JSONEncoder().encode(warning)
        let decoded = try JSONDecoder().decode(AlertWarning.self, from: encoded)

        XCTAssertEqual(warning, decoded, "Warning should round-trip through JSON encoding")
    }

    func testDefaultWarnings() {
        let defaults = AlertWarning.defaultWarnings

        XCTAssertEqual(defaults.count, 2, "Should have 2 default warnings")
        XCTAssertEqual(defaults[0].minutesBefore, 5, "First default warning should be 5 minutes")
        XCTAssertEqual(defaults[1].minutesBefore, 1, "Second default warning should be 1 minute")
    }

    // MARK: - Warnings Array Tests

    func testDefaultWarningsReturned() {
        // Fresh preferences should return default warnings
        XCTAssertEqual(preferences.warnings.count, 2, "Should have 2 warnings by default")
        XCTAssertEqual(preferences.warnings[0].minutesBefore, 5, "First warning should be 5 minutes")
        XCTAssertEqual(preferences.warnings[1].minutesBefore, 1, "Second warning should be 1 minute")
    }

    func testSetWarnings() {
        let newWarnings = [
            AlertWarning(minutesBefore: 10, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 3, sound: "fire-alarm-bell", soundDuration: 4.0),
            AlertWarning(minutesBefore: 1, sound: "fire-alarm-bell", soundDuration: 4.0)
        ]

        preferences.warnings = newWarnings

        XCTAssertEqual(preferences.warnings.count, 3, "Should have 3 warnings after setting")
        XCTAssertEqual(preferences.warnings[0].minutesBefore, 10, "First warning should be 10 minutes")
        XCTAssertEqual(preferences.warnings[1].minutesBefore, 3, "Second warning should be 3 minutes")
        XCTAssertEqual(preferences.warnings[2].minutesBefore, 1, "Third warning should be 1 minute")
    }

    func testWarningsPersistence() {
        let newWarnings = [
            AlertWarning(minutesBefore: 15, sound: "fire-alarm-bell", soundDuration: 4.0)
        ]

        preferences.warnings = newWarnings

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertEqual(newPreferences.warnings.count, 1, "Warnings should persist")
        XCTAssertEqual(newPreferences.warnings[0].minutesBefore, 15, "Warning minutes should persist")
    }

    func testEmptyWarningsArray() {
        preferences.warnings = []

        XCTAssertEqual(preferences.warnings.count, 0, "Should allow empty warnings array")
    }

    func testSingleWarning() {
        let singleWarning = [AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0)]
        preferences.warnings = singleWarning

        XCTAssertEqual(preferences.warnings.count, 1, "Should allow single warning")
    }

    func testManyWarnings() {
        let manyWarnings = (1...10).map { AlertWarning(minutesBefore: $0, sound: "fire-alarm-bell", soundDuration: 4.0) }
        preferences.warnings = manyWarnings

        XCTAssertEqual(preferences.warnings.count, 10, "Should allow many warnings")
    }

    // MARK: - Event Start Sound Tests

    func testDefaultEventStartSoundDuration() {
        XCTAssertEqual(preferences.eventStartSoundDuration, 4.0, "Event start sound should default to 4 seconds")
    }

    func testSetEventStartSoundDuration() {
        preferences.eventStartSoundDuration = 6.0
        XCTAssertEqual(preferences.eventStartSoundDuration, 6.0, "Event start sound duration should be settable")
    }

    func testEventStartSoundDurationPersistence() {
        preferences.eventStartSoundDuration = 8.0

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertEqual(newPreferences.eventStartSoundDuration, 8.0, "Event start sound duration should persist")
    }

    // MARK: - Alert Sound Tests

    func testDefaultAlertSound() {
        XCTAssertEqual(preferences.alertSound, "fire-alarm-bell", "Alert sound should default to fire-alarm-bell")
    }

    func testSetAlertSound() {
        preferences.alertSound = "other-sound"
        XCTAssertEqual(preferences.alertSound, "other-sound", "Alert sound should be settable")
    }

    func testEmptyAlertSound() {
        preferences.alertSound = ""
        XCTAssertEqual(preferences.alertSound, "", "Alert sound should allow empty string for no audio")
    }

    func testAlertSoundPersistence() {
        preferences.alertSound = "custom-sound"

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertEqual(newPreferences.alertSound, "custom-sound", "Alert sound should persist")
    }

    // MARK: - Available Sounds Tests

    func testAvailableSoundsIncludesNoAudio() {
        let sounds = Preferences.availableSounds
        XCTAssertTrue(sounds.contains { $0.id == "" && $0.name == "No audio" }, "Available sounds should include 'No audio' option")
    }

    func testAvailableSoundsIncludesFireAlarmBell() {
        let sounds = Preferences.availableSounds
        XCTAssertTrue(sounds.contains { $0.id == "fire-alarm-bell" }, "Available sounds should include fire-alarm-bell")
    }

    func testDisplayNameConversion() {
        let sounds = Preferences.availableSounds
        let alarmBell = sounds.first { $0.id == "fire-alarm-bell" }
        XCTAssertEqual(alarmBell?.name, "Alarm Bell", "fire-alarm-bell should display as 'Alarm Bell'")

        // Verify prefixes are removed
        let mixkitSound = sounds.first { $0.id == "mixkit-alarm-tone" }
        XCTAssertEqual(mixkitSound?.name, "Alarm Tone", "mixkit prefix should be removed")

        let soundbibleSound = sounds.first { $0.id == "soundbible-air-horn" }
        XCTAssertEqual(soundbibleSound?.name, "Air Horn", "soundbible prefix should be removed")
    }

    func testAvailableSoundsCount() {
        let sounds = Preferences.availableSounds
        XCTAssertEqual(sounds.count, 11, "Should have 11 options: No audio + 10 sound files")
    }

    func testNoAudioIsFirstOption() {
        let sounds = Preferences.availableSounds
        XCTAssertEqual(sounds.first?.id, "", "First option should be 'No audio' with empty id")
        XCTAssertEqual(sounds.first?.name, "No audio", "First option should be named 'No audio'")
    }

    func testAllSoundFilesExistInBundle() {
        let sounds = Preferences.availableSounds.filter { !$0.id.isEmpty }
        for sound in sounds {
            let url = Bundle.main.url(forResource: sound.id, withExtension: "mp3")
            XCTAssertNotNil(url, "Sound file '\(sound.id).mp3' should exist in bundle")
        }
    }

    func testAllSoundFilesArePlayable() {
        let sounds = Preferences.availableSounds.filter { !$0.id.isEmpty }
        for sound in sounds {
            guard let url = Bundle.main.url(forResource: sound.id, withExtension: "mp3") else {
                XCTFail("Sound file '\(sound.id).mp3' not found")
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                XCTAssertTrue(player.duration > 0, "Sound file '\(sound.id).mp3' should have positive duration")
            } catch {
                XCTFail("Sound file '\(sound.id).mp3' should be playable: \(error)")
            }
        }
    }

    func testAllExpectedSoundsAreAvailable() {
        let expectedSounds = [
            "fire-alarm-bell",
            "mixkit-alarm-tone",
            "mixkit-alert-bells-echo",
            "mixkit-battleship-alarm",
            "mixkit-classic-short-alarm",
            "mixkit-urgent-simple-tone",
            "mixkit-warning-alarm-buzzer",
            "soundbible-air-horn",
            "soundbible-red-alert",
            "soundbible-school-fire-alarm"
        ]
        let availableIds = Preferences.availableSounds.map { $0.id }
        for expected in expectedSounds {
            XCTAssertTrue(availableIds.contains(expected), "Should include '\(expected)' in available sounds")
        }
    }

    // MARK: - Keys Tests

    func testKeysAreCorrect() {
        XCTAssertEqual(Preferences.Keys.warnings, "warnings")
        XCTAssertEqual(Preferences.Keys.eventStartSoundDuration, "eventStartSoundDuration")
        XCTAssertEqual(Preferences.Keys.alertSound, "alertSound")
    }

    // MARK: - Shared Instance Tests

    func testSharedInstanceExists() {
        XCTAssertNotNil(Preferences.shared, "Shared preferences instance should exist")
    }

    func testSharedInstanceIsSingleton() {
        let instance1 = Preferences.shared
        let instance2 = Preferences.shared
        XCTAssertTrue(instance1 === instance2, "Shared should return the same instance")
    }

    // MARK: - Calendar Selection Tests

    func testDefaultCalendarState() {
        // All calendars should be enabled by default (empty disabled list)
        XCTAssertEqual(preferences.disabledCalendarIDs.count, 0, "No calendars should be disabled by default")
    }

    func testDisableCalendar() {
        preferences.setCalendar("test-calendar-1", enabled: false)
        XCTAssertFalse(preferences.isCalendarEnabled("test-calendar-1"), "Calendar should be disabled")
        XCTAssertEqual(preferences.disabledCalendarIDs, ["test-calendar-1"], "Disabled list should contain calendar")
    }

    func testEnableDisabledCalendar() {
        preferences.setCalendar("test-calendar-1", enabled: false)
        preferences.setCalendar("test-calendar-1", enabled: true)
        XCTAssertTrue(preferences.isCalendarEnabled("test-calendar-1"), "Calendar should be enabled")
        XCTAssertEqual(preferences.disabledCalendarIDs.count, 0, "Disabled list should be empty")
    }

    func testMultipleDisabledCalendars() {
        preferences.setCalendar("calendar-1", enabled: false)
        preferences.setCalendar("calendar-2", enabled: false)
        preferences.setCalendar("calendar-3", enabled: false)

        XCTAssertEqual(preferences.disabledCalendarIDs.count, 3, "Should have 3 disabled calendars")
        XCTAssertFalse(preferences.isCalendarEnabled("calendar-1"), "Calendar 1 should be disabled")
        XCTAssertFalse(preferences.isCalendarEnabled("calendar-2"), "Calendar 2 should be disabled")
        XCTAssertFalse(preferences.isCalendarEnabled("calendar-3"), "Calendar 3 should be disabled")
    }

    func testEnableOneOfMultipleDisabled() {
        preferences.setCalendar("calendar-1", enabled: false)
        preferences.setCalendar("calendar-2", enabled: false)
        preferences.setCalendar("calendar-1", enabled: true)

        XCTAssertTrue(preferences.isCalendarEnabled("calendar-1"), "Calendar 1 should be enabled")
        XCTAssertFalse(preferences.isCalendarEnabled("calendar-2"), "Calendar 2 should be disabled")
        XCTAssertEqual(preferences.disabledCalendarIDs, ["calendar-2"], "Only calendar-2 should be in disabled list")
    }

    func testDisablingAlreadyDisabledCalendar() {
        preferences.setCalendar("calendar-1", enabled: false)
        preferences.setCalendar("calendar-1", enabled: false)

        XCTAssertEqual(preferences.disabledCalendarIDs.count, 1, "Should not duplicate disabled calendar")
    }

    func testEnablingAlreadyEnabledCalendar() {
        preferences.setCalendar("calendar-1", enabled: true)
        XCTAssertTrue(preferences.isCalendarEnabled("calendar-1"), "Calendar should be enabled")
        XCTAssertEqual(preferences.disabledCalendarIDs.count, 0, "Disabled list should remain empty")
    }

    func testNewCalendarEnabledByDefault() {
        // A calendar not in disabledCalendarIDs should be enabled
        XCTAssertTrue(preferences.isCalendarEnabled("new-calendar-999"), "New calendar should be enabled by default")
    }

    func testDisabledCalendarsPersistence() {
        preferences.setCalendar("calendar-1", enabled: false)
        preferences.setCalendar("calendar-2", enabled: false)

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertFalse(newPreferences.isCalendarEnabled("calendar-1"), "Calendar 1 should remain disabled")
        XCTAssertFalse(newPreferences.isCalendarEnabled("calendar-2"), "Calendar 2 should remain disabled")
        XCTAssertEqual(newPreferences.disabledCalendarIDs.count, 2, "Should have 2 disabled calendars after reload")
    }

    // MARK: - TitleIgnoreList

    func testTitleIgnoreMatchesCaseInsensitiveSubstring() {
        let list = TitleIgnoreList(patterns: ["OOTO"])
        XCTAssertTrue(list.matches("ooto - team offsite"), "Unanchored, case-insensitive substring matches")
    }

    func testTitleIgnoreAnchoredPatternMatchesExactly() {
        let list = TitleIgnoreList(patterns: ["^Busy$"])
        XCTAssertTrue(list.matches("Busy"))
        XCTAssertFalse(list.matches("Busy with client"), "Anchored pattern only matches the exact title")
    }

    func testTitleIgnoreMatchesAnyPattern() {
        let list = TitleIgnoreList(patterns: ["Unavailable", "OOTO"])
        XCTAssertTrue(list.matches("OOTO"))
        XCTAssertTrue(list.matches("Unavailable"))
        XCTAssertFalse(list.matches("Sprint planning"))
    }

    func testTitleIgnoreSkipsBlankPatterns() {
        let list = TitleIgnoreList(patterns: ["   ", ""])
        XCTAssertFalse(list.matches("Any meeting"), "Blank patterns must not match everything")
    }

    func testTitleIgnoreSkipsInvalidRegex() {
        let list = TitleIgnoreList(patterns: ["["]) // invalid regex
        XCTAssertFalse(list.matches("[ bracket meeting"), "Invalid regex is skipped, not fatal")
    }

    func testTitleIgnoreNilOrEmptyTitleNeverMatches() {
        let list = TitleIgnoreList(patterns: ["OOTO"])
        XCTAssertFalse(list.matches(nil))
        XCTAssertFalse(list.matches(""))
    }

    func testTitleIgnoreParseSplitsTrimsAndDropsEmpties() {
        let parsed = TitleIgnoreList.parse("OOTO\n  Unavailable  \n\n\t\nBusy")
        XCTAssertEqual(parsed, ["OOTO", "Unavailable", "Busy"])
    }

    func testIgnoredTitlePatternsPersistenceRoundTrip() {
        let suite = "IgnoreTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.ignoredTitlePatterns, [], "Default is empty")
        prefs.ignoredTitlePatterns = ["OOTO", "Unavailable"]
        XCTAssertEqual(Preferences(defaults: defaults).ignoredTitlePatterns, ["OOTO", "Unavailable"])
    }

    // MARK: - WorkingHours

    /// Build a date at a known weekday/time. 2026-06-28 is a Sunday (weekday 1);
    /// adding (weekday-1) days yields the requested weekday.
    private func whDate(weekday: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 28 + (weekday - 1)
        comps.hour = hour; comps.minute = minute
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(Calendar.current.component(.weekday, from: date), weekday, "date helper weekday sanity")
        return date
    }

    func testWorkingHoursDisabledAlwaysAllows() {
        let wh = WorkingHours(enabled: false, startMinutes: 540, endMinutes: 1020, activeDays: [2])
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 1, hour: 3, minute: 0)))
    }

    func testWorkingHoursDaytimeInWindow() {
        let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 10, minute: 0)))
    }

    func testWorkingHoursDaytimeBeforeAndAfterSuppress() {
        let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
        XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 8, minute: 30)))
        XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 17, minute: 30)))
    }

    func testWorkingHoursDaytimeBoundariesInclusive() {
        let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2])
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 9, minute: 0)), "start inclusive")
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 17, minute: 0)), "end inclusive")
    }

    func testWorkingHoursInactiveDaySuppresses() {
        let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
        XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 1, hour: 10, minute: 0)), "Sunday inactive")
    }

    func testWorkingHoursWrappingNightShift() {
        let wh = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2])
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 23, minute: 30)), "after start, before midnight")
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 2, minute: 0)), "after midnight, before end")
        XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 12, minute: 0)), "midday outside")
    }

    func testWorkingHoursWrappingBoundariesInclusive() {
        let wh = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2])
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 23, minute: 0)), "start inclusive")
        XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 7, minute: 0)), "end inclusive")
    }

    func testWorkingHoursPersistenceRoundTrip() {
        let suite = "WorkingHoursTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)

        XCTAssertFalse(prefs.workingHours.enabled, "Default disabled")

        prefs.workingHours = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2, 4])
        let reloaded = Preferences(defaults: defaults).workingHours
        XCTAssertEqual(reloaded.enabled, true)
        XCTAssertEqual(reloaded.startMinutes, 23 * 60)
        XCTAssertEqual(reloaded.endMinutes, 7 * 60)
        XCTAssertEqual(reloaded.activeDays, [2, 4])
    }
}
