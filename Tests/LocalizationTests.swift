import XCTest
@testable import Klaxon

final class LocalizationTests: XCTestCase {

    // All supported language codes
    static let supportedLanguages = [
        "en", "es", "fr", "de", "it", "pt", "nl", "ja", "zh-Hans", "ko", "sw",
        "tr", "el", "ru", "pl", "uk", "cs", "sk", "sr", "hr", "bg",
        "vi", "th", "id", "ms", "fil", "zh-Hant", "ar"
    ]

    // Get the bundle containing Klaxon's resources (works in both app and test contexts)
    static var klaxonBundle: Bundle {
        // In tests, Bundle.main is the test runner. We need the Klaxon app bundle.
        // Bundle(for:) with a class from Klaxon gives us the correct bundle.
        Bundle(for: AppDelegate.self)
    }

    // All localization keys used in the app
    static let allKeys = [
        // App General
        "app.name",
        // Menu Bar
        "menu.about", "menu.preferences", "menu.respectDND", "menu.quit",
        // Preferences Window
        "preferences.title",
        // Tab Labels
        "preferences.tab.alert", "preferences.tab.calendar", "preferences.tab.other",
        // Event Alert Section
        "preferences.eventAlert.header", "preferences.eventAlert.description",
        "preferences.eventAlert.playSound", "preferences.eventAlert.duration",
        // Calendars Section
        "preferences.calendars.header", "preferences.calendars.description",
        "preferences.calendars.noCalendarsEnabled",
        // Warnings Section
        "preferences.warningAlerts.header", "preferences.warningAlerts.description",
        "preferences.warningAlerts.addButton", "preferences.warningAlerts.column.when",
        "preferences.warningAlerts.column.playSound", "preferences.warningAlerts.column.duration",
        "preferences.warningAlerts.minBeforeEvent",
        // Do Not Disturb Section
        "preferences.dnd.header", "preferences.dnd.respectFocus",
        // General Section
        "preferences.general.header", "preferences.general.startAtLogin",
        "preferences.general.showWelcome",
        // Buttons
        "preferences.button.ok",
        // Duration Options
        "preferences.duration.noSound", "preferences.duration.oneSecond",
        "preferences.duration.seconds",
        // Sound Names
        "sound.noAudio", "sound.alarmBell", "sound.alarmTone",
        "sound.alertBellsEcho", "sound.battleshipAlarm", "sound.classicShortAlarm",
        "sound.urgentSimpleTone", "sound.warningAlarmBuzzer", "sound.airHorn",
        "sound.redAlert", "sound.schoolFireAlarm",
        // Alert Window
        "alert.warning.title", "alert.starting.title",
        "alert.warning.message", "alert.warning.messagePlural",
        "alert.starting.message", "alert.startTime", "alert.location",
        "alert.untitledEvent", "alert.button.dismiss", "alert.button.openEvent",
        "alert.button.join",
        // Welcome Window
        "welcome.title", "welcome.copyright", "welcome.description",
        "welcome.button.ok",
        // About Window
        "about.title", "about.version", "about.copyright", "about.license",
        "about.description", "about.assistive", "about.credits.header",
        "about.credits.icon", "about.credits.sound1", "about.credits.sound2",
        "about.credits.sound3", "about.credits.sound4", "about.license.header",
        // Calendar Access
        "calendar.accessRequired.title", "calendar.accessRequired.message",
        "calendar.accessRequired.retry", "calendar.accessRequired.quit",
        // Login Item
        "loginItem.error.title",
        // Accessibility Labels - Alert Window
        "accessibility.alert.dismissButton", "accessibility.alert.openEventButton",
        "accessibility.alert.joinButton", "accessibility.alert.joinButtonUnavailable",
        "accessibility.alert.joinLink",
        // Accessibility Labels - Welcome Window
        "accessibility.welcome.okButton",
        // Accessibility Labels - About Window
        "accessibility.about.okButton",
        // Accessibility Labels - Preferences Window
        "accessibility.preferences.okButton", "accessibility.preferences.tabView",
        "accessibility.preferences.alertSound", "accessibility.preferences.alertDuration",
        "accessibility.preferences.warningsTable", "accessibility.preferences.addWarning",
        "accessibility.preferences.removeWarning", "accessibility.preferences.calendarsTable",
        "accessibility.preferences.calendarCheckbox"
    ]

    // MARK: - Localization File Existence Tests

    func testAllLocalizationFilesExist() {
        for language in Self.supportedLanguages {
            let bundle = Self.klaxonBundle
            let lprojPath = bundle.path(forResource: language, ofType: "lproj")
            XCTAssertNotNil(lprojPath, "Localization folder '\(language).lproj' should exist")

            if let lprojPath = lprojPath {
                let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
                let fileExists = FileManager.default.fileExists(atPath: stringsPath)
                XCTAssertTrue(fileExists, "Localizable.strings should exist in '\(language).lproj'")
            }
        }
    }

    func testSupportedLanguagesCount() {
        XCTAssertEqual(Self.supportedLanguages.count, 28, "Should support 28 languages")
    }

    // MARK: - Key Coverage Tests

    func testEnglishHasAllKeys() {
        // English is the base language and should have all keys
        for key in Self.allKeys {
            let value = NSLocalizedString(key, tableName: nil, bundle: Self.klaxonBundle, value: "NOT_FOUND", comment: "")
            XCTAssertNotEqual(value, "NOT_FOUND", "English should have translation for '\(key)'")
            XCTAssertNotEqual(value, "", "English translation for '\(key)' should not be empty")
        }
    }

    func testAllKeysCount() {
        XCTAssertEqual(Self.allKeys.count, 92, "Should have 92 localization keys defined")
    }

    // MARK: - Language-specific Tests

    func testLanguageHasRequiredKeys() {
        // Test that critical UI keys exist for each language
        let criticalKeys = [
            "menu.about", "menu.preferences", "menu.quit",
            "preferences.button.ok", "alert.button.dismiss"
        ]

        for language in Self.supportedLanguages {
            guard let lprojPath = Self.klaxonBundle.path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: lprojPath) else {
                continue // Skip if bundle not found (will be caught by existence test)
            }

            for key in criticalKeys {
                let value = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: "NOT_FOUND", comment: "")
                XCTAssertNotEqual(value, "NOT_FOUND", "Language '\(language)' should have translation for critical key '\(key)'")
            }
        }
    }

    // MARK: - Format String Tests

    func testFormatStringsHaveCorrectPlaceholders() {
        // Keys that require format specifiers
        let formatKeys: [(key: String, specifier: String)] = [
            ("preferences.duration.seconds", "%d"),
            ("alert.warning.title", "%d"),
            ("alert.warning.message", "%d"),
            ("alert.warning.messagePlural", "%d"),
            ("alert.startTime", "%@"),
            ("alert.location", "%@"),
            ("welcome.copyright", "%d"),
            ("about.version", "%@"),
            ("about.copyright", "%d")
        ]

        for (key, specifier) in formatKeys {
            for language in Self.supportedLanguages {
                guard let lprojPath = Self.klaxonBundle.path(forResource: language, ofType: "lproj"),
                      let bundle = Bundle(path: lprojPath) else {
                    continue
                }

                let value = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: "", comment: "")
                if !value.isEmpty {
                    XCTAssertTrue(value.contains(specifier),
                        "Language '\(language)' key '\(key)' should contain '\(specifier)' format specifier")
                }
            }
        }
    }

    // MARK: - RTL Language Tests

    func testArabicLocalizationExists() {
        let lprojPath = Self.klaxonBundle.path(forResource: "ar", ofType: "lproj")
        XCTAssertNotNil(lprojPath, "Arabic localization should exist for RTL support")
    }

    // MARK: - CJK Language Tests

    func testCJKLanguagesExist() {
        let cjkLanguages = ["ja", "ko", "zh-Hans", "zh-Hant"]
        for language in cjkLanguages {
            let lprojPath = Self.klaxonBundle.path(forResource: language, ofType: "lproj")
            XCTAssertNotNil(lprojPath, "CJK language '\(language)' localization should exist")
        }
    }

    // MARK: - Cyrillic Language Tests

    func testCyrillicLanguagesExist() {
        let cyrillicLanguages = ["ru", "uk", "bg", "sr"]
        for language in cyrillicLanguages {
            let lprojPath = Self.klaxonBundle.path(forResource: language, ofType: "lproj")
            XCTAssertNotNil(lprojPath, "Cyrillic language '\(language)' localization should exist")
        }
    }
}
