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
        [("", "No audio")] + soundFiles.map { ($0, displayName(for: $0)) }
    }

    /// Convert a sound filename to a display name (title case, dashes/underscores to spaces)
    private static func displayName(for filename: String) -> String {
        // Special case for fire-alarm-bell
        if filename == "fire-alarm-bell" {
            return "Alarm Bell"
        }

        // Remove source prefixes
        var name = filename
            .replacingOccurrences(of: "mixkit-", with: "")
            .replacingOccurrences(of: "soundbible-", with: "")

        // Convert to title case
        return name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
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
            Keys.showWindowOnLaunch: true
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
