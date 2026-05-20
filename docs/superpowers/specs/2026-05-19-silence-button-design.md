# Silence Button — Design

**Date:** 2026-05-19
**Status:** Approved
**Feature:** Add a "Silence" button to the alarm modal that suppresses the remaining alarms for its event.

## Problem

Klaxon delivers up to three escalating alerts per event (e.g. 5-minute warning, 1-minute warning, event starting). Once a user has acknowledged an event at the first alert, the later alerts for that same event are noise. There is currently no way to say "I've got it — stop alerting me about this one."

## Goal

When an alarm modal is showing, the user can click **Silence** to suppress every remaining alarm for that event occurrence. The current modal closes and its sound stops, exactly as the existing actions do.

## Decisions

| Question | Decision |
|----------|----------|
| Recurring events: occurrence or series? | **Single occurrence.** Silencing today's standup leaves tomorrow's intact. Keyed on `eventIdentifier` + occurrence `startDate`. |
| Persistence across app restart? | **In-memory only.** Consistent with the existing `notifiedEvents` ledger. A restart forgets silences. |
| Modal layout for a 4th button? | **Widen the window** from 500pt to 580pt content width. |
| Behavior on the final (event-starting) alert? | **Uniform.** Silence is always enabled; at every stage it stops the sound, records the silence, and closes. On the final alert the record step is a harmless no-op. |

## Architecture

Information flows one way today:

```
CalendarService --onEventAlert--> AppDelegate --> AlertWindowController
```

Silence needs a path back. It mirrors the existing `onEventAlert` pattern with a second closure, `onSilence`:

```
AlertWindowController --onSilence--> AppDelegate --> CalendarService.silence(_:)
```

## Components

### 1. `CalendarService` — suppression state

The alarm engine already keeps a per-event ledger, `notifiedEvents: [String: Set<AlertType>]`, that makes a scan skip alerts it has already fired. Silence is the same idea — skip an occurrence's remaining alerts — but it must be per-occurrence, because every occurrence of a recurring event shares one `eventIdentifier`.

A separate set keeps intent legible: `notifiedEvents` means "fired," `silencedOccurrences` means "suppressed." They are never confused.

```swift
struct SilencedOccurrence: Hashable {
    let eventIdentifier: String
    let startDate: Date
}

private var silencedOccurrences: Set<SilencedOccurrence> = []
```

- **`silence(_ event: EKEvent)`** — extracts `eventIdentifier` and `startDate`, inserts a `SilencedOccurrence`. No-op if the event has no identifier.
- **`scanCalendars`** — at the top of the per-event loop, if a `SilencedOccurrence` matching the event exists, `continue`. This skips all remaining alerts for that occurrence: every configured warning and the event-starting alert.
- **Cleanup** — because the key carries `startDate`, pruning is a one-liner: drop occurrences whose `startDate` is more than one hour past. This is simpler than the existing `cleanupOldEventIDs`, which requires a calendar query.

The membership check and pruning are written as pure functions over `SilencedOccurrence` values so they can be unit-tested without a real saved `EKEvent` (test-built events have a `nil` `eventIdentifier`).

### 2. `AlertWindowController` — the Silence button

- Window content width grows **500pt → 580pt**. The event-detail text column (`rightWidth`) widens from 320pt to ~400pt, giving long titles, locations, and meeting URLs more room before truncating. Window height stays 220pt.
- The bottom button row holds four buttons, left to right: **Join · Open Calendar · Silence · Dismiss**. Dismiss stays rightmost (muscle memory, Escape). Silence sits beside it — both close the modal; Silence also suppresses.
- Silence is always enabled.
- New init parameter: `onSilence: ((EKEvent) -> Void)? = nil`, the same shape as `WelcomeWindowController.onDismiss`.
- New action `silenceAlert()` — at every alert stage: `stopAlertSound()`, `onSilence?(event)`, `close()`.
- Key equivalents unchanged: Escape → Dismiss, Enter → Join (or Open Calendar when there is no meeting link). Silence is click-only.

### 3. `AppDelegate` — wiring

`showEventAlert` constructs the controller with the silence closure:

```swift
alertWindowController = AlertWindowController(
    event: event,
    alertType: alertType,
    onSilence: { [weak self] in self?.calendarService?.silence($0) }
)
```

### 4. Localization

Two new keys are added to all 28 `.lproj/Localizable.strings` files:

- `alert.button.silence` — the button title.
- `accessibility.alert.silenceButton` — the VoiceOver label.

Both keys are **properly translated into every one of the 28 languages** as part of this work — matching the standard set by commit `977c013` ("rename Open Event button to Open Calendar with translations"), not left as English placeholders. `LocalizationTests` enforces key parity across locales, so the keys must exist in every file regardless.

## Edge cases

| Case | Behavior |
|------|----------|
| Silence on the event-starting (final) alert | Stops the sound and closes. `onSilence` records an occurrence no future alert will match — a harmless no-op. |
| App restarts before the event begins | Silence is forgotten (in-memory). Remaining alerts may fire again. Accepted. |
| Event is rescheduled after being silenced | The occurrence's `startDate` changes, so the silence key no longer matches and alerts resume. Accepted — a moved meeting is worth re-alerting. |
| Two events alert near-simultaneously | `showEventAlert` already replaces the prior modal. Each modal carries its own event; Silence affects only that event. |

## Testing

**`CalendarServiceTests`** — pure tests over `SilencedOccurrence`:

- A silenced occurrence is skipped by the scan logic.
- An occurrence with a *different* `startDate` is **not** skipped (proves per-occurrence isolation for recurring events).
- An occurrence more than an hour past is pruned by cleanup.

**`AlertWindowTests`**:

- The window contains a Silence button.
- The window content width is 580pt (updates `testAlertWindowHasCorrectSize`).
- The Silence action invokes the `onSilence` closure with the event and closes the window.

### Adjacent fix (standalone commit)

`AlertWindowTests` line 89 searches for the button title `"Open Event"`, but commit `977c013` renamed the button to "Open Calendar", leaving that test stale. This is unrelated to the Silence feature, so it lands as its **own commit, made first** — before any Silence work — keeping the fix isolated and the feature commits clean.

## Out of scope

- Persisting silences to disk.
- Silencing an entire recurring series.
- A UI to view or un-silence currently silenced events.
- A keyboard shortcut for Silence.
