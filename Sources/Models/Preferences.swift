import Foundation

final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    /// Available alert sounds (filename without extension)
    private static let soundFiles = ["fire-alarm-bell"]

    /// Available alert sounds with display names
    static var availableSounds: [(id: String, name: String)] {
        [("", "No audio")] + soundFiles.map { ($0, displayName(for: $0)) }
    }

    /// Convert a sound filename to a display name (title case, dashes/underscores to spaces)
    private static func displayName(for filename: String) -> String {
        filename
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    enum Keys {
        static let firstAlertEnabled = "firstAlertEnabled"
        static let firstAlertMinutes = "firstAlertMinutes"
        static let firstAlertSoundDuration = "firstAlertSoundDuration"
        static let secondAlertEnabled = "secondAlertEnabled"
        static let secondAlertMinutes = "secondAlertMinutes"
        static let secondAlertSoundDuration = "secondAlertSoundDuration"
        static let eventStartSoundDuration = "eventStartSoundDuration"
        static let alertSound = "alertSound"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.firstAlertEnabled: true,
            Keys.firstAlertMinutes: 5,
            Keys.firstAlertSoundDuration: 1.0,
            Keys.secondAlertEnabled: true,
            Keys.secondAlertMinutes: 1,
            Keys.secondAlertSoundDuration: 2.0,
            Keys.eventStartSoundDuration: 4.0,
            Keys.alertSound: "fire-alarm-bell"
        ])
    }

    var firstAlertEnabled: Bool {
        get { defaults.bool(forKey: Keys.firstAlertEnabled) }
        set { defaults.set(newValue, forKey: Keys.firstAlertEnabled) }
    }

    var firstAlertMinutes: Int {
        get { defaults.integer(forKey: Keys.firstAlertMinutes) }
        set { defaults.set(newValue, forKey: Keys.firstAlertMinutes) }
    }

    var secondAlertEnabled: Bool {
        get { defaults.bool(forKey: Keys.secondAlertEnabled) }
        set { defaults.set(newValue, forKey: Keys.secondAlertEnabled) }
    }

    var secondAlertMinutes: Int {
        get { defaults.integer(forKey: Keys.secondAlertMinutes) }
        set { defaults.set(newValue, forKey: Keys.secondAlertMinutes) }
    }

    /// Sound duration in seconds for first alert (0 = no sound)
    var firstAlertSoundDuration: Double {
        get { defaults.double(forKey: Keys.firstAlertSoundDuration) }
        set { defaults.set(newValue, forKey: Keys.firstAlertSoundDuration) }
    }

    /// Sound duration in seconds for second alert (0 = no sound)
    var secondAlertSoundDuration: Double {
        get { defaults.double(forKey: Keys.secondAlertSoundDuration) }
        set { defaults.set(newValue, forKey: Keys.secondAlertSoundDuration) }
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
}
