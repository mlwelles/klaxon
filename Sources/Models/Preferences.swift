import AVFoundation
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
}
