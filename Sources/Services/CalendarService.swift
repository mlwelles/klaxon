import EventKit
import Foundation

enum AlertType: Hashable {
    case warning(minutes: Int, sound: String, soundDuration: Double)
    case eventStarting
}

final class CalendarService {
    private let eventStore: EKEventStore
    private var scanTimer: Timer?
    private var notifiedEvents: [String: Set<AlertType>] = [:]

    var onEventAlert: ((EKEvent, AlertType) -> Void)?

    private let scanIntervalSeconds: TimeInterval = 30
    private let lookAheadHours: Int = 3

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    func startMonitoring() {
        scanCalendars()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanIntervalSeconds, repeats: true) { [weak self] _ in
            self?.scanCalendars()
        }
    }

    func stopMonitoring() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func scanCalendars() {
        // Skip alerts if DND is active and user has enabled the preference
        if Preferences.shared.respectDoNotDisturb && Preferences.isDoNotDisturbActive() {
            return
        }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: lookAheadHours, to: now) ?? now

        // Get all calendars and filter to only enabled ones
        let allCalendars = eventStore.calendars(for: .event)
        let enabledCalendars = allCalendars.filter { calendar in
            Preferences.shared.isCalendarEnabled(calendar.calendarIdentifier)
        }

        // If no calendars are enabled, return early (no events to scan)
        guard !enabledCalendars.isEmpty else { return }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: enabledCalendars)
        let events = eventStore.events(matching: predicate)

        let prefs = Preferences.shared

        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
            var sentAlerts = notifiedEvents[eventID] ?? []

            // Check each configured warning
            for warning in prefs.warnings {
                let alertSeconds = TimeInterval(warning.minutesBefore * 60)
                let alertType = AlertType.warning(minutes: warning.minutesBefore, sound: warning.sound, soundDuration: warning.soundDuration)
                if timeUntilStart <= alertSeconds && timeUntilStart > alertSeconds - 30 && !sentAlerts.contains(alertType) {
                    sentAlerts.insert(alertType)
                    notifiedEvents[eventID] = sentAlerts
                    onEventAlert?(event, alertType)
                }
            }

            // Event starting (between 0 and -30 seconds)
            if timeUntilStart <= 0 && timeUntilStart > -30 && !sentAlerts.contains(.eventStarting) {
                sentAlerts.insert(.eventStarting)
                notifiedEvents[eventID] = sentAlerts
                onEventAlert?(event, .eventStarting)
            }
        }

        cleanupOldEventIDs()
    }

    private func cleanupOldEventIDs() {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()

        let allCalendars = eventStore.calendars(for: .event)
        let enabledCalendars = allCalendars.filter { calendar in
            Preferences.shared.isCalendarEnabled(calendar.calendarIdentifier)
        }

        guard !enabledCalendars.isEmpty else {
            notifiedEvents = [:]
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: cutoffDate,
            end: Date(),
            calendars: enabledCalendars
        )
        let recentEvents = eventStore.events(matching: predicate)
        let recentIDs = Set(recentEvents.compactMap { $0.eventIdentifier })

        notifiedEvents = notifiedEvents.filter { recentIDs.contains($0.key) }
    }
}
