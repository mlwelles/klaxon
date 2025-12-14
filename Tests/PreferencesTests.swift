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
}
