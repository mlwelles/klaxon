import EventKit
import Foundation

enum AlertType {
    case fiveMinuteWarning
    case oneMinuteWarning
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

        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
            var sentAlerts = notifiedEvents[eventID] ?? []

            // 5 minute warning (between 5:00 and 4:30 minutes before)
            if timeUntilStart <= 300 && timeUntilStart > 270 && !sentAlerts.contains(.fiveMinuteWarning) {
                sentAlerts.insert(.fiveMinuteWarning)
                notifiedEvents[eventID] = sentAlerts
                onEventAlert?(event, .fiveMinuteWarning)
            }

            // 1 minute warning (between 1:00 and 0:30 minutes before)
            if timeUntilStart <= 60 && timeUntilStart > 30 && !sentAlerts.contains(.oneMinuteWarning) {
                sentAlerts.insert(.oneMinuteWarning)
                notifiedEvents[eventID] = sentAlerts
                onEventAlert?(event, .oneMinuteWarning)
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
