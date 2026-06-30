# Design: Silence reliability, occurrence-aware scanning, working hours, and title filters

Date: 2026-06-29
Status: Approved

## Summary

Three changes to Klaxon's alert pipeline, all refining the "should this alert
fire?" decision in `CalendarService.scanCalendars()`:

- **Change A — Occurrence-aware scan.** Make the scan track *occurrences*, not
  events. This fixes the Silence button (silencing currently fails to suppress
  remaining alerts), guarantees per-occurrence silence for recurring events,
  fixes a latent recurring-event alert-dedup bug, and always ignores all-day
  events. Diagnostics are added to confirm behavior in the field.
- **Change B — Working hours.** A toggleable daily window (with a weekday
  picker) that may wrap past midnight. When enabled, alerts fire only for events
  that *start* inside the window on an active day.
- **Change C — Title ignore patterns.** A configurable list of regular
  expressions. An event whose title matches any pattern never triggers an alert
  (e.g. "Unavailable", "OOTO" blocks).

The three changes ship as one spec and one plan because they touch the same scan
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

1. `event.isAllDay` → skip (always, no preference).
2. Title matches an ignore pattern (Change C) → skip.
3. Outside working hours (Change B) → skip.
4. Occurrence silenced → skip.
5. Otherwise evaluate warnings and the event-starting alert against
   `notifiedEvents[key]`.

Gates 1–3 are content/time filters that skip the event before any tracking
state is touched; gate 4 is the per-occurrence silence check.

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

`allows` returns `true` when `!enabled` — the feature is an on/off toggle, and
when off the gate disappears entirely. When enabled, it returns `true` only when
the event's start weekday is in `activeDays` **and** its minute-of-day falls
within the window. The window may wrap past midnight:

- `startMinutes <= endMinutes` (e.g. 09:00–17:00): in-window when
  `start ≤ minuteOfDay ≤ end`.
- `startMinutes > endMinutes` (e.g. 23:00–07:00, a night shift): in-window when
  `minuteOfDay ≥ start` **or** `minuteOfDay ≤ end`.

There is no "daytime only" restriction and no "overnight" special case — a night
worker's "from 11pm to 7am" is as valid as a day worker's "from 9am to 5pm". The
weekday check uses the event's own calendar weekday (the day the event shows on
the calendar), so it matches what the user sees.

**Defaults:** disabled, 09:00–17:00, Mon–Fri (`{2,3,4,5,6}`). Shipping disabled
means existing users see no behavior change until they opt in.

**Gating semantics:** the window applies to the event's *start time*, not to
wall-clock time at firing. An event that starts inside the window keeps all its
alerts, including a pre-warning that lands a few minutes before the window opens.

**Preferences integration:** store the `WorkingHours` as JSON `Data` under a
single key, exposed as a computed property — mirroring the existing `warnings`
property.

**Scan integration:** one per-event line —
`if !prefs.workingHours.allows(eventStart: event.startDate) { continue }` —
at gate position 3 above.

**UI:** a "Working Hours" section on a new shared **"Filters"** tab in
`PreferencesWindowController` (see Change C, which adds a second section to the
same tab). Controls: an enable checkbox, a "from" and a "to" `NSDatePicker`
(`.hourMinute`), seven weekday checkboxes, and a note. Time and day controls
disable when the checkbox is off, following the existing
`updateSoundControlsEnabled()` idiom. Weekday labels come from
`Calendar.current.shortWeekdaySymbols`, already localized by the OS. The window
may wrap past midnight, so the UI imposes no "end after start" constraint.

## Change C: Title ignore patterns

### Problem

Users block time in a work calendar with placeholder events ("Unavailable",
"OOTO", "Busy") that mirror commitments held elsewhere. These should never raise
a Klaxon alarm. There is no way today to suppress alerts by event title.

### Design

**New value type** `TitleIgnoreList` (pure, testable):

```swift
struct TitleIgnoreList {
    let patterns: [String]
    func matches(_ title: String?) -> Bool
}
```

`matches` returns `true` if the title contains a match for any pattern. Rules:

- **Case-insensitive, unanchored.** A pattern matches when found anywhere in the
  title (`NSRegularExpression.firstMatch` with `.caseInsensitive`). So plain
  substrings like `OOTO` work; power users can anchor (`^Busy$`) or use full
  regex syntax.
- **Empty patterns are skipped.** Each pattern is trimmed; blank entries are
  ignored. This is a safety requirement — an empty regex matches *everything*, so
  a stray blank line must never suppress all alerts.
- **Invalid patterns are skipped**, never fatal. A pattern that fails to compile
  is treated as non-matching, and the scan continues. (The matcher stays a pure
  value type; per-scan logging would spam, so invalid patterns are silently
  inert. Surfacing them in the UI is a future enhancement — see Out of scope.)
- A nil or empty title never matches.

**Defaults:** empty list. Existing users see no change until they add a pattern.

**Preferences integration:** store the patterns as `[String]` under one key, via
`UserDefaults.stringArray` — mirroring `disabledCalendarIDs`.

**Scan integration:** at gate position 2 —
`if TitleIgnoreList(patterns: prefs.ignoredTitlePatterns).matches(event.title) { continue }`.

**UI:** an "Ignore Events by Title" section on the shared "Filters" tab. A
scrollable `NSTextView` holds one pattern per line; a note shows examples. The
text-to-list parsing (`split on newlines → trim → drop empties`) is a pure helper
so it can be unit-tested apart from the view. Patterns persist on edit.

## Testing

Tests are thorough by intent: every new branch and every documented edge case
gets a test. Run logic tests freely; defer window-showing tests and ask before
running them (the app pops blocking modals).

**Change A — occurrence-aware scan (logic):**
- `OccurrenceKey` from two `startDate`s differing by sub-second yields one key.
- `OccurrenceKey` from starts one minute apart yields two distinct keys.
- Identifier resolution: `eventIdentifier` wins; nil falls back to
  `calendarItemExternalIdentifier`; both nil falls back to `title`; empty strings
  count as missing.
- The same factory feeds `silence()` and the scan decision (consistency).
- Silencing occurrence A of a recurring event does not suppress occurrence B.
- Recorded-alert state for occurrence A does not suppress occurrence B's alerts.
- `shouldEvaluate` skips all-day events, ignored-title events, out-of-window
  events, and silenced occurrences; allows an otherwise-eligible event.
- Pruning drops silenced and notified entries older than one hour and keeps
  recent ones.

**Change B — working hours (logic):**
- `enabled == false` always allows.
- Daytime window: in-window allows; before and after suppress; both boundaries
  inclusive.
- Wrapping (night-shift) window (23:00–07:00): a time after start (23:30) and a
  time before end (02:00) allow; a midday time (12:00) suppresses; both
  boundaries inclusive.
- Inactive weekday suppresses even when the time is in-window.
- Persistence round-trips `enabled`, `startMinutes`, `endMinutes`, `activeDays`,
  including a wrapping window.

**Change C — title ignore patterns (logic):**
- A plain substring pattern matches case-insensitively ("ooto" matches "OOTO -
  offsite").
- An anchored pattern (`^Busy$`) matches only the exact title.
- Multiple patterns: a title matching any one is ignored.
- A blank/whitespace-only pattern is skipped (does not suppress everything).
- An invalid regex is skipped (does not crash, does not match).
- Nil and empty titles never match.
- Text parsing: newline-separated text splits into trimmed, non-empty patterns;
  round-trips through the preference.

**i18n:**
- `LocalizationTests` confirm the new keys exist with identical key sets across
  all 28 locales.

**Deferred (UI):**
- Filters tab load/save, enable/disable behavior, and pattern-text round-trip.

## Out of scope

- Persisting silenced occurrences across app restarts (in-memory; pruned after an
  hour; the app runs continuously).
- Per-day working-hours windows (a single window, applied on the selected days).
- A preference to re-enable all-day alerts (they are always ignored).
- Live regex validation feedback in the UI (invalid patterns are simply skipped
  at scan time; a future enhancement could flag them as the user types).
- Matching ignore patterns against fields other than the title (location, notes).
