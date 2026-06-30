# Design: Silence reliability, occurrence-aware scanning, and working hours

Date: 2026-06-29
Status: Approved

## Summary

Two changes to Klaxon's alert pipeline, both refining the "should this alert
fire?" decision in `CalendarService.scanCalendars()`:

- **Change A — Occurrence-aware scan.** Make the scan track *occurrences*, not
  events. This fixes the Silence button (silencing currently fails to suppress
  remaining alerts), guarantees per-occurrence silence for recurring events,
  fixes a latent recurring-event alert-dedup bug, and always ignores all-day
  events. Diagnostics are added to confirm behavior in the field.
- **Change B — Working hours.** A configurable daily window with a weekday
  picker. Alerts fire only for events that *start* inside the window on an
  active day.

The two changes ship as one spec and one plan because they touch the same scan
loop, but they are independent in behavior.

## Background

`scanCalendars()` runs every 30 seconds, fetches events starting within the next
3 hours, and fires up to three alerts per event (configurable warnings plus an
"event starting now" alert). It already has two suppression gates: a per-event
silence check and a global Do Not Disturb early-return.

Today the scan keys its tracking state on `eventIdentifier` and a raw `Date`:

- `silencedOccurrences: Set<SilencedOccurrence>` where `SilencedOccurrence` holds
  `eventIdentifier` and `startDate` (a `Date`).
- `notifiedEvents: [String: Set<AlertType>]` keyed by `eventIdentifier` alone.

## Change A: Occurrence-aware scan

### Problem

1. **Silence does not suppress remaining alerts.** The occurrence key is derived
   independently at two call sites — `silence(event)` and `scanCalendars()` — and
   depends on exact `Date` equality plus a non-nil `eventIdentifier`.
   `SilencedOccurrence` is `Hashable`, so a `Set` lookup misses on any
   sub-second or floating-point drift between the two derivations. When
   `eventIdentifier` is nil, `silence()` silently no-ops via its
   `guard let … else { return }`.
2. **Recurring-event dedup is not per-occurrence.** `notifiedEvents` is keyed by
   `eventIdentifier` only. All occurrences of a recurring event share one
   identifier, so they share one "already alerted" set. Symptom: a later
   occurrence's alerts can be suppressed because an earlier occurrence already
   fired. (This is the inverse of bug 1 — the same defect from the other side.)
3. **All-day events alert.** Out-of-office blocks, holidays, and birthdays carry
   a midnight `startDate`, so the scan fires an "event starting now" alarm at
   00:00 and pre-warnings the night before.

### Design

For a recurring event, every field except the start time is shared across
occurrences (`eventIdentifier`, `calendarItemExternalIdentifier`, `title`). The
start time alone distinguishes occurrences. Per-occurrence correctness therefore
depends on a key that always includes a normalized start time, derived through a
single function.

**1. One shared `OccurrenceKey`** (generalizes the current `SilencedOccurrence`):

```swift
struct OccurrenceKey: Hashable {
    let identifier: String   // eventIdentifier ?? calendarItemExternalIdentifier ?? title
    let startSecond: Int     // Int(startDate.timeIntervalSinceReferenceDate.rounded())
}
```

- A single factory builds the key. Both `silence()` and the scan derive the key
  through it, so the two paths cannot diverge.
- The factory exposes a primitive-input overload
  `OccurrenceKey(identifier:externalIdentifier:title:startDate:)` plus a thin
  `OccurrenceKey(event:)` convenience. The primitive overload makes the
  normalization unit-testable without EventKit.
- Whole-second rounding removes sub-second/float drift. It never merges distinct
  occurrences: recurrence rules space occurrences at least 60 seconds apart.
- Identifier fallback removes the silent-no-op failure mode. A nil
  `eventIdentifier` falls back to `calendarItemExternalIdentifier`, then `title`.
  Falling back to `title` logs a warning.

**2. Both tracking maps key on `OccurrenceKey`:**

- `silencedOccurrences: Set<OccurrenceKey>` — fixes the Silence button.
  Silencing today's 09:00 standup leaves tomorrow's untouched because
  `startSecond` differs.
- `notifiedEvents: [OccurrenceKey: Set<AlertType>]` — each occurrence accrues its
  own alert set, so a recurring event alerts correctly on every occurrence.

**3. All-day filter.** The per-event loop skips `event.isAllDay` first, before any
identity, silence, or working-hours check. This is unconditional (no preference),
per the requirement to always ignore all-day events.

**4. Unified, time-based pruning.** Because the key carries `startSecond`, both
maps prune by dropping entries whose start is more than one hour past. This
replaces `cleanupOldEventIDs()` and its event-store re-query; pruning by the
key's own timestamp is simpler and independent of what the store still returns.

**5. Diagnostics.** Add an `os.Logger` (subsystem from the bundle identifier,
category `scan`). Log the resolved key when silencing, when the scan skips a
silenced occurrence, and when an alert is about to fire. Event titles are logged
with `.private` privacy. This lets us compare keys between silence-time and
fire-time in Console.app and confirm the fix in the field.

### Scan gate order (per event)

1. `event.isAllDay` → skip.
2. Outside working hours (Change B) → skip.
3. Occurrence silenced → skip.
4. Otherwise evaluate warnings and the event-starting alert against
   `notifiedEvents[key]`.

## Change B: Working hours

### Design

**New value type** `WorkingHours` (`Codable`, `Equatable`):

```swift
struct WorkingHours: Codable, Equatable {
    var enabled: Bool
    var startMinutes: Int          // minutes since midnight, 540 = 09:00
    var endMinutes: Int            // 1020 = 17:00
    var activeDays: Set<Int>       // Calendar weekday numbers, 1 = Sun … 7 = Sat

    func allows(eventStart date: Date, calendar: Calendar = .current) -> Bool
}
```

`allows` returns `true` when `!enabled`. Otherwise it returns `true` only when
the event's start weekday is in `activeDays` and its minute-of-day falls within
the inclusive range `startMinutes...endMinutes`.

**Defaults:** disabled, 09:00–17:00, Mon–Fri (`{2,3,4,5,6}`). Shipping disabled
means existing users see no behavior change until they opt in.

**Scope (v1):** daytime window only (`startMinutes < endMinutes`); the UI enforces
end after start. Overnight windows that cross midnight are out of scope.

**Gating semantics:** the window applies to the event's *start time*, not to
wall-clock time at firing. An event that starts inside the window keeps all its
alerts, including a pre-warning that lands a few minutes before the window opens.

**Preferences integration:** store the `WorkingHours` as JSON `Data` under a
single key, exposed as a computed property — mirroring the existing `warnings`
property.

**Scan integration:** one per-event line —
`if !prefs.workingHours.allows(eventStart: event.startDate) { continue }` —
at gate position 2 above.

**UI:** a new "Schedule" tab in `PreferencesWindowController`. Controls: an enable
checkbox, two `NSDatePicker`s (`.hourMinute`), seven weekday checkboxes, and a
note label. Time and day controls disable when the checkbox is off, following the
existing `updateSoundControlsEnabled()` idiom. Weekday labels come from
`Calendar.current.shortWeekdaySymbols`, already localized by the OS.

**i18n:** roughly four new strings (tab title, "Enable working hours",
"From"/"to", a note), added across all 28 locales. Weekday names need no new
translations because the OS provides localized symbols.

## Testing

Run logic tests freely; defer window-showing tests and ask before running them
(the app pops blocking modals).

**Change A (logic):**
- Two `startDate`s differing by sub-second yield the same `OccurrenceKey`.
- Nil `eventIdentifier` falls back to `calendarItemExternalIdentifier`; both nil
  falls back to `title` without crashing.
- The same factory feeds `silence()` and the scan (consistency).
- Silencing occurrence A of a recurring event does not suppress occurrence B.
- An alert fired for occurrence A does not suppress occurrence B's alerts.
- The all-day filter drops `isAllDay` events.

**Change B (logic):**
- `allows` — in-hours fires; before/after window suppressed; inactive weekday
  suppressed; `enabled == false` always allows; boundaries at exactly start and
  end; weekend off.

**Deferred (UI):**
- Schedule tab load/save and enable/disable behavior.

## Out of scope

- Persisting silenced occurrences across app restarts (in-memory; pruned after an
  hour; the app runs continuously).
- Overnight working-hours windows.
- Per-day working-hours windows.
- A preference to re-enable all-day alerts.
