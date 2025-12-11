import EventKit
import Foundation

enum AlertType: Hashable {
    case firstWarning(minutes: Int)
    case secondWarning(minutes: Int)
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
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: lookAheadHours, to: now) ?? now

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        let prefs = Preferences.shared

        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
            var sentAlerts = notifiedEvents[eventID] ?? []

            // First warning (configurable minutes before)
            if prefs.firstAlertEnabled {
                let firstAlertSeconds = TimeInterval(prefs.firstAlertMinutes * 60)
                let firstAlertType = AlertType.firstWarning(minutes: prefs.firstAlertMinutes)
                if timeUntilStart <= firstAlertSeconds && timeUntilStart > firstAlertSeconds - 30 && !sentAlerts.contains(firstAlertType) {
                    sentAlerts.insert(firstAlertType)
                    notifiedEvents[eventID] = sentAlerts
                    onEventAlert?(event, firstAlertType)
                }
            }

            // Second warning (configurable minutes before)
            if prefs.secondAlertEnabled {
                let secondAlertSeconds = TimeInterval(prefs.secondAlertMinutes * 60)
                let secondAlertType = AlertType.secondWarning(minutes: prefs.secondAlertMinutes)
                if timeUntilStart <= secondAlertSeconds && timeUntilStart > secondAlertSeconds - 30 && !sentAlerts.contains(secondAlertType) {
                    sentAlerts.insert(secondAlertType)
                    notifiedEvents[eventID] = sentAlerts
                    onEventAlert?(event, secondAlertType)
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

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(
            withStart: cutoffDate,
            end: Date(),
            calendars: calendars
        )
        let recentEvents = eventStore.events(matching: predicate)
        let recentIDs = Set(recentEvents.compactMap { $0.eventIdentifier })

        notifiedEvents = notifiedEvents.filter { recentIDs.contains($0.key) }
    }
}
