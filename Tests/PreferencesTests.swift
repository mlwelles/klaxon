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

    // MARK: - Default Values Tests

    func testDefaultFirstAlertEnabled() {
        XCTAssertTrue(preferences.firstAlertEnabled, "First alert should be enabled by default")
    }

    func testDefaultFirstAlertMinutes() {
        XCTAssertEqual(preferences.firstAlertMinutes, 5, "First alert should default to 5 minutes")
    }

    func testDefaultSecondAlertEnabled() {
        XCTAssertTrue(preferences.secondAlertEnabled, "Second alert should be enabled by default")
    }

    func testDefaultSecondAlertMinutes() {
        XCTAssertEqual(preferences.secondAlertMinutes, 1, "Second alert should default to 1 minute")
    }

    // MARK: - First Alert Tests

    func testSetFirstAlertEnabled() {
        preferences.firstAlertEnabled = false
        XCTAssertFalse(preferences.firstAlertEnabled, "First alert enabled should be settable to false")

        preferences.firstAlertEnabled = true
        XCTAssertTrue(preferences.firstAlertEnabled, "First alert enabled should be settable to true")
    }

    func testSetFirstAlertMinutes() {
        preferences.firstAlertMinutes = 10
        XCTAssertEqual(preferences.firstAlertMinutes, 10, "First alert minutes should be settable")

        preferences.firstAlertMinutes = 30
        XCTAssertEqual(preferences.firstAlertMinutes, 30, "First alert minutes should be updatable")
    }

    func testFirstAlertMinutesPersistence() {
        preferences.firstAlertMinutes = 15

        // Create a new Preferences instance with the same UserDefaults
        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertEqual(newPreferences.firstAlertMinutes, 15, "First alert minutes should persist")
    }

    func testFirstAlertEnabledPersistence() {
        preferences.firstAlertEnabled = false

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertFalse(newPreferences.firstAlertEnabled, "First alert enabled should persist")
    }

    // MARK: - Second Alert Tests

    func testSetSecondAlertEnabled() {
        preferences.secondAlertEnabled = false
        XCTAssertFalse(preferences.secondAlertEnabled, "Second alert enabled should be settable to false")

        preferences.secondAlertEnabled = true
        XCTAssertTrue(preferences.secondAlertEnabled, "Second alert enabled should be settable to true")
    }

    func testSetSecondAlertMinutes() {
        preferences.secondAlertMinutes = 3
        XCTAssertEqual(preferences.secondAlertMinutes, 3, "Second alert minutes should be settable")

        preferences.secondAlertMinutes = 2
        XCTAssertEqual(preferences.secondAlertMinutes, 2, "Second alert minutes should be updatable")
    }

    func testSecondAlertMinutesPersistence() {
        preferences.secondAlertMinutes = 7

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertEqual(newPreferences.secondAlertMinutes, 7, "Second alert minutes should persist")
    }

    func testSecondAlertEnabledPersistence() {
        preferences.secondAlertEnabled = false

        let newPreferences = Preferences(defaults: testDefaults)
        XCTAssertFalse(newPreferences.secondAlertEnabled, "Second alert enabled should persist")
    }

    // MARK: - Edge Cases

    func testFirstAlertMinutesMinValue() {
        preferences.firstAlertMinutes = 1
        XCTAssertEqual(preferences.firstAlertMinutes, 1, "First alert should accept minimum value of 1")
    }

    func testFirstAlertMinutesMaxValue() {
        preferences.firstAlertMinutes = 60
        XCTAssertEqual(preferences.firstAlertMinutes, 60, "First alert should accept maximum value of 60")
    }

    func testSecondAlertMinutesMinValue() {
        preferences.secondAlertMinutes = 1
        XCTAssertEqual(preferences.secondAlertMinutes, 1, "Second alert should accept minimum value of 1")
    }

    func testSecondAlertMinutesMaxValue() {
        preferences.secondAlertMinutes = 60
        XCTAssertEqual(preferences.secondAlertMinutes, 60, "Second alert should accept maximum value of 60")
    }

    func testZeroMinutesValue() {
        // While the UI enforces min of 1, the model should handle 0
        preferences.firstAlertMinutes = 0
        XCTAssertEqual(preferences.firstAlertMinutes, 0, "First alert should accept 0 minutes")

        preferences.secondAlertMinutes = 0
        XCTAssertEqual(preferences.secondAlertMinutes, 0, "Second alert should accept 0 minutes")
    }

    // MARK: - Independence Tests

    func testAlertsAreIndependent() {
        preferences.firstAlertEnabled = false
        preferences.secondAlertEnabled = true

        XCTAssertFalse(preferences.firstAlertEnabled, "First alert state should be independent")
        XCTAssertTrue(preferences.secondAlertEnabled, "Second alert state should be independent")
    }

    func testAlertMinutesAreIndependent() {
        preferences.firstAlertMinutes = 10
        preferences.secondAlertMinutes = 2

        XCTAssertEqual(preferences.firstAlertMinutes, 10, "First alert minutes should be independent")
        XCTAssertEqual(preferences.secondAlertMinutes, 2, "Second alert minutes should be independent")
    }

    // MARK: - Keys Tests

    func testKeysAreCorrect() {
        XCTAssertEqual(Preferences.Keys.firstAlertEnabled, "firstAlertEnabled")
        XCTAssertEqual(Preferences.Keys.firstAlertMinutes, "firstAlertMinutes")
        XCTAssertEqual(Preferences.Keys.secondAlertEnabled, "secondAlertEnabled")
        XCTAssertEqual(Preferences.Keys.secondAlertMinutes, "secondAlertMinutes")
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
