import EventKit
import Foundation
import os

enum AlertType: Hashable {
    case warning(minutes: Int, sound: String, soundDuration: Double)
    case eventStarting
}

/// Identifies one occurrence of an event. Recurring occurrences share an
/// identifier but differ by start time, so the key combines a stable identifier
/// with a whole-second-normalized start (defeating sub-second float drift across
/// separate event-store fetches).
struct OccurrenceKey: Hashable {
    let identifier: String
    let startSecond: Int

    init(identifier: String, startSecond: Int) {
        self.identifier = identifier
        self.startSecond = startSecond
    }

    init(identifier: String, startDate: Date) {
        self.init(identifier: identifier, startSecond: OccurrenceKey.second(from: startDate))
    }

    init(eventIdentifier: String?, externalIdentifier: String?, title: String?, startDate: Date) {
        let resolved = OccurrenceKey.resolveIdentifier(
            eventIdentifier: eventIdentifier,
            externalIdentifier: externalIdentifier,
            title: title
        )
        self.init(identifier: resolved, startDate: startDate)
    }

    static func second(from date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate.rounded())
    }

    static func resolveIdentifier(eventIdentifier: String?, externalIdentifier: String?, title: String?) -> String {
        if let id = eventIdentifier, !id.isEmpty { return id }
        if let ext = externalIdentifier, !ext.isEmpty { return ext }
        if let title = title, !title.isEmpty { return title }
        return ""
    }
}

extension OccurrenceKey {
    init(event: EKEvent) {
        self.init(
            eventIdentifier: event.eventIdentifier,
            externalIdentifier: event.calendarItemExternalIdentifier,
            title: event.title,
            startDate: event.startDate
        )
    }
}

final class CalendarService {
    private let eventStore: EKEventStore
    private var scanTimer: Timer?
    private var notifiedEvents: [OccurrenceKey: Set<AlertType>] = [:]
    private var silencedOccurrences: Set<OccurrenceKey> = []
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mlwelles.klaxon", category: "scan")

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

    /// Suppress all remaining alerts for this event's occurrence.
    func silence(_ event: EKEvent) {
        if event.eventIdentifier == nil {
            log.warning("Silencing event with no eventIdentifier; using fallback key")
        }
        silence(key: OccurrenceKey(event: event))
    }

    func silence(key: OccurrenceKey) {
        silencedOccurrences.insert(key)
        log.notice("Silenced occurrence id=\(key.identifier, privacy: .private) sec=\(key.startSecond, privacy: .public)")
    }

    func isSilenced(_ key: OccurrenceKey) -> Bool {
        silencedOccurrences.contains(key)
    }

    // Back-compat convenience.
    func silenceOccurrence(eventIdentifier: String, startDate: Date) {
        silence(key: OccurrenceKey(identifier: eventIdentifier, startDate: startDate))
    }

    func isOccurrenceSilenced(eventIdentifier: String, startDate: Date) -> Bool {
        isSilenced(OccurrenceKey(identifier: eventIdentifier, startDate: startDate))
    }

    func wasAlertSent(_ type: AlertType, for key: OccurrenceKey) -> Bool {
        notifiedEvents[key]?.contains(type) ?? false
    }

    func recordAlert(_ type: AlertType, for key: OccurrenceKey) {
        notifiedEvents[key, default: []].insert(type)
    }

    /// Decide whether an event's occurrence should be evaluated for alerts this scan.
    /// Gate order: all-day, ignored title, working hours, silenced.
    func shouldEvaluate(isAllDay: Bool, title: String?, eventStart: Date, key: OccurrenceKey,
                        workingHours: WorkingHours, ignoreList: TitleIgnoreList) -> Bool {
        if isAllDay { return false }
        if ignoreList.matches(title) { return false }
        if !workingHours.allows(eventStart: eventStart) { return false }
        if isSilenced(key) { return false }
        return true
    }

    /// Drop silenced and notified entries whose start is more than an hour past.
    func pruneState(referenceDate: Date = Date()) {
        let cutoff = OccurrenceKey.second(from: referenceDate) - 3600
        silencedOccurrences = silencedOccurrences.filter { $0.startSecond > cutoff }
        notifiedEvents = notifiedEvents.filter { $0.key.startSecond > cutoff }
    }

    // Back-compat alias.
    func pruneSilencedOccurrences(referenceDate: Date = Date()) {
        pruneState(referenceDate: referenceDate)
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
        let workingHours = prefs.workingHours
        let ignoreList = TitleIgnoreList(patterns: prefs.ignoredTitlePatterns)

        for event in events {
            let key = OccurrenceKey(event: event)
            guard shouldEvaluate(isAllDay: event.isAllDay, title: event.title, eventStart: event.startDate,
                                 key: key, workingHours: workingHours, ignoreList: ignoreList) else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)

            // Check each configured warning
            for warning in prefs.warnings {
                let alertSeconds = TimeInterval(warning.minutesBefore * 60)
                let alertType = AlertType.warning(minutes: warning.minutesBefore, sound: warning.sound, soundDuration: warning.soundDuration)
                if timeUntilStart <= alertSeconds && timeUntilStart > alertSeconds - 30 && !wasAlertSent(alertType, for: key) {
                    recordAlert(alertType, for: key)
                    log.notice("Firing \(warning.minutesBefore, privacy: .public)-min warning sec=\(key.startSecond, privacy: .public)")
                    onEventAlert?(event, alertType)
                }
            }

            // Event starting (between 0 and -30 seconds)
            if timeUntilStart <= 0 && timeUntilStart > -30 && !wasAlertSent(.eventStarting, for: key) {
                recordAlert(.eventStarting, for: key)
                log.notice("Firing event-starting sec=\(key.startSecond, privacy: .public)")
                onEventAlert?(event, .eventStarting)
            }
        }

        pruneState()
    }
}
