import AVFoundation
import EventKit
import Foundation

/// A configurable warning that fires before an event starts
struct AlertWarning: Codable, Equatable {
    var minutesBefore: Int
    var sound: String
    var soundDuration: Double

    static let defaultWarnings: [AlertWarning] = [
        AlertWarning(minutesBefore: 5, sound: "fire-alarm-bell", soundDuration: 4.0),
        AlertWarning(minutesBefore: 1, sound: "fire-alarm-bell", soundDuration: 4.0)
    ]
}

final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    /// Available alert sounds (filename without extension), sorted alphabetically
    private static let soundFiles = [
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

    /// Available alert sounds with display names
    static var availableSounds: [(id: String, name: String)] {
        [("", NSLocalizedString("sound.noAudio", comment: "No audio option"))] + soundFiles.map { ($0, displayName(for: $0)) }
    }

    /// Cache of sound durations
    private static var soundDurationCache: [String: Double] = [:]

    /// Get the actual duration of a sound file in seconds
    static func soundDuration(for soundName: String) -> Double {
        if soundName.isEmpty { return 0 }
        if let cached = soundDurationCache[soundName] { return cached }

        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return 0 }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let duration = player.duration
            soundDurationCache[soundName] = duration
            return duration
        } catch {
            return 0
        }
    }

    /// Convert a sound filename to a localized display name
    private static func displayName(for filename: String) -> String {
        switch filename {
        case "fire-alarm-bell":
            return NSLocalizedString("sound.alarmBell", comment: "Alarm Bell sound")
        case "mixkit-alarm-tone":
            return NSLocalizedString("sound.alarmTone", comment: "Alarm Tone sound")
        case "mixkit-alert-bells-echo":
            return NSLocalizedString("sound.alertBellsEcho", comment: "Alert Bells Echo sound")
        case "mixkit-battleship-alarm":
            return NSLocalizedString("sound.battleshipAlarm", comment: "Battleship Alarm sound")
        case "mixkit-classic-short-alarm":
            return NSLocalizedString("sound.classicShortAlarm", comment: "Classic Short Alarm sound")
        case "mixkit-urgent-simple-tone":
            return NSLocalizedString("sound.urgentSimpleTone", comment: "Urgent Simple Tone sound")
        case "mixkit-warning-alarm-buzzer":
            return NSLocalizedString("sound.warningAlarmBuzzer", comment: "Warning Alarm Buzzer sound")
        case "soundbible-air-horn":
            return NSLocalizedString("sound.airHorn", comment: "Air Horn sound")
        case "soundbible-red-alert":
            return NSLocalizedString("sound.redAlert", comment: "Red Alert sound")
        case "soundbible-school-fire-alarm":
            return NSLocalizedString("sound.schoolFireAlarm", comment: "School Fire Alarm sound")
        default:
            // Fallback: convert to title case
            return filename
                .replacingOccurrences(of: "mixkit-", with: "")
                .replacingOccurrences(of: "soundbible-", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        }
    }

    enum Keys {
        static let warnings = "warnings"
        static let eventStartSoundDuration = "eventStartSoundDuration"
        static let alertSound = "alertSound"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let showWindowOnLaunch = "showWindowOnLaunch"
        static let disabledCalendarIDs = "disabledCalendarIDs"
        static let respectDoNotDisturb = "respectDoNotDisturb"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.eventStartSoundDuration: 4.0,
            Keys.alertSound: "fire-alarm-bell",
            Keys.showWindowOnLaunch: false
        ])
    }

    /// Configurable warnings before events
    var warnings: [AlertWarning] {
        get {
            guard let data = defaults.data(forKey: Keys.warnings),
                  let decoded = try? JSONDecoder().decode([AlertWarning].self, from: data) else {
                return AlertWarning.defaultWarnings
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.warnings)
            }
        }
    }

    /// Sound duration in seconds for event start alert (0 = no sound)
    var eventStartSoundDuration: Double {
        get { defaults.double(forKey: Keys.eventStartSoundDuration) }
        set { defaults.set(newValue, forKey: Keys.eventStartSoundDuration) }
    }

    /// Selected alert sound filename (without extension), empty string means no audio
    var alertSound: String {
        get { defaults.string(forKey: Keys.alertSound) ?? "fire-alarm-bell" }
        set { defaults.set(newValue, forKey: Keys.alertSound) }
    }

    /// Whether the app has been launched before
    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    /// Whether to show the welcome window on manual launch
    var showWindowOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.showWindowOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.showWindowOnLaunch) }
    }

    /// Whether to respect system Do Not Disturb / Focus mode
    var respectDoNotDisturb: Bool {
        get { defaults.bool(forKey: Keys.respectDoNotDisturb) }
        set { defaults.set(newValue, forKey: Keys.respectDoNotDisturb) }
    }

    /// Check if system Do Not Disturb / Focus mode is currently active
    static func isDoNotDisturbActive() -> Bool {
        // On macOS 12+, Focus modes are stored in a different location
        // We check the assertion state which is more reliable across versions
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        task.arguments = [
            "-extract", "dnd_prefs.userPref.enabled", "raw",
            "-o", "-",
            NSString(string: "~/Library/DoNotDisturb/DB/Assertions.json").expandingTildeInPath
        ]

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "1" || output.lowercased() == "true"
            }
        } catch {
            // Fall back to checking ModeConfigurations
        }

        // Fallback: Check for active Focus mode via ModeConfigurations
        let modeConfigPath = NSString(string: "~/Library/DoNotDisturb/DB/ModeConfigurations.json").expandingTildeInPath
        if let data = FileManager.default.contents(atPath: modeConfigPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let modeData = json["data"] as? [[String: Any]] {
            for mode in modeData {
                if let isActive = mode["isActive"] as? Bool, isActive {
                    return true
                }
            }
        }

        return false
    }

    /// Calendar identifiers that are disabled (not monitored)
    var disabledCalendarIDs: [String] {
        get {
            return defaults.stringArray(forKey: Keys.disabledCalendarIDs) ?? []
        }
        set {
            defaults.set(newValue, forKey: Keys.disabledCalendarIDs)
        }
    }

    /// Check if a calendar is enabled for monitoring
    func isCalendarEnabled(_ calendarID: String) -> Bool {
        return !disabledCalendarIDs.contains(calendarID)
    }

    /// Enable or disable a calendar
    func setCalendar(_ calendarID: String, enabled: Bool) {
        var disabled = disabledCalendarIDs
        if enabled {
            disabled.removeAll { $0 == calendarID }
        } else if !disabled.contains(calendarID) {
            disabled.append(calendarID)
        }
        disabledCalendarIDs = disabled
    }

    /// Remove calendar IDs that no longer exist in the event store
    func cleanupDeletedCalendars(eventStore: EKEventStore) {
        let currentIDs = Set(eventStore.calendars(for: .event).map { $0.calendarIdentifier })
        disabledCalendarIDs = disabledCalendarIDs.filter { currentIDs.contains($0) }
    }
}
