import Foundation

final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    enum Keys {
        static let firstAlertEnabled = "firstAlertEnabled"
        static let firstAlertMinutes = "firstAlertMinutes"
        static let secondAlertEnabled = "secondAlertEnabled"
        static let secondAlertMinutes = "secondAlertMinutes"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.firstAlertEnabled: true,
            Keys.firstAlertMinutes: 5,
            Keys.secondAlertEnabled: true,
            Keys.secondAlertMinutes: 1
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
}
