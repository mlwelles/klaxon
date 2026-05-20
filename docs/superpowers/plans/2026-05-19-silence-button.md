# Silence Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Silence" button to the alarm modal that suppresses every remaining alarm for the event occurrence it belongs to.

**Architecture:** A new in-memory `Set<SilencedOccurrence>` in `CalendarService` records silenced occurrences keyed by `eventIdentifier` + `startDate`; `scanCalendars` skips any occurrence in that set. The alarm modal gains a fourth button whose action flows back through a new `onSilence` closure: `AlertWindowController` → `AppDelegate` → `CalendarService.silence(_:)`. The modal widens from 500pt to 580pt to hold the extra button.

**Tech Stack:** Swift, AppKit, EventKit, AVFoundation, XCTest, `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-05-19-silence-button-design.md`

---

## File Structure

No new files. All changes modify existing files:

| File | Responsibility | Change |
|------|----------------|--------|
| `Sources/Services/CalendarService.swift` | Alarm engine + suppression state | Add `SilencedOccurrence` struct, silence/prune methods, scan-loop skip |
| `Sources/Views/AlertWindowController.swift` | Alarm modal UI | Widen window, add Silence button + `onSilence` callback |
| `Sources/App/AppDelegate.swift` | Wires modal to service | Pass `onSilence` closure into the modal |
| `Sources/Resources/*.lproj/Localizable.strings` (28 files) | Localized strings | Add `alert.button.silence` + `accessibility.alert.silenceButton` |
| `Tests/CalendarServiceTests.swift` | Service unit tests | Add silence/prune tests |
| `Tests/AlertWindowTests.swift` | Modal unit tests | Fix stale title, update size, add Silence-button tests |
| `Tests/LocalizationTests.swift` | Localization coverage | Register the two new keys |

`SilencedOccurrence` lives at file scope inside `CalendarService.swift`, alongside the existing file-scope `enum AlertType` — matching the established pattern, so no new file and no Xcode project surgery.

## Test Commands

- **Full suite:** `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'`
- **One test class:** append `-only-testing:KlaxonTests/CalendarServiceTests`
- **One test method:** append `-only-testing:KlaxonTests/CalendarServiceTests/testSilenceOccurrenceMarksItSilenced`
- **Build only:** `xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Debug build`

The test target is `KlaxonTests`; the scheme is `Klaxon`.

---

## Task 1: Fix stale "Open Event" button-title assertion (standalone commit)

Commit `977c013` renamed the modal's button from "Open Event" to "Open Calendar", but `AlertWindowTests` line ~89 still searches for the old title. This is unrelated to the Silence feature, so it lands first as its own commit, giving a clean green baseline.

**Files:**
- Modify: `Tests/AlertWindowTests.swift` (function `testAlertWindowContainsOpenEventButton`)

- [ ] **Step 1: Run the stale test to confirm it currently fails**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests/testAlertWindowContainsOpenEventButton`
Expected: FAIL — `findButton(in:withTitle: "Open Event")` returns `nil` because the button title is now "Open Calendar".

- [ ] **Step 2: Update the test to the current button title**

Replace the whole `testAlertWindowContainsOpenEventButton` function with:

```swift
    @MainActor
    func testAlertWindowContainsOpenEventButton() {
        let controller = AlertWindowController(event: mockEvent)

        let contentView = controller.window?.contentView
        let openEventButton = findButton(in: contentView, withTitle: "Open Calendar")

        XCTAssertNotNil(openEventButton, "Window should contain an Open Calendar button")
        XCTAssertEqual(openEventButton?.keyEquivalent, "\r", "Open Calendar button should respond to Enter key")
    }
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests/testAlertWindowContainsOpenEventButton`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Tests/AlertWindowTests.swift
git commit -m "test: fix stale Open Calendar button title assertion"
```

---

## Task 2: Add per-occurrence silence tracking to CalendarService

Introduce the `SilencedOccurrence` value type and the in-memory store plus its pure operations. All logic here is unit-tested directly — no real `EKEvent` needed (test-built `EKEvent`s have a `nil` `eventIdentifier`, so the testable surface takes primitives).

**Files:**
- Modify: `Sources/Services/CalendarService.swift`
- Test: `Tests/CalendarServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

Add this section to `Tests/CalendarServiceTests.swift`, immediately before the closing brace of the `CalendarServiceTests` class:

```swift
    // MARK: - Silence Tests

    func testSilencedOccurrenceEquality() {
        let start = Date()
        let a = SilencedOccurrence(eventIdentifier: "e", startDate: start)
        let b = SilencedOccurrence(eventIdentifier: "e", startDate: start)
        let c = SilencedOccurrence(eventIdentifier: "e", startDate: start.addingTimeInterval(60))

        XCTAssertEqual(a, b, "Same identifier and start date should be equal")
        XCTAssertNotEqual(a, c, "Different start dates should not be equal")
    }

    func testSilenceOccurrenceMarksItSilenced() {
        let service = CalendarService(eventStore: EKEventStore())
        let start = Date()

        service.silenceOccurrence(eventIdentifier: "event-1", startDate: start)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "event-1", startDate: start),
            "Occurrence should be silenced after silenceOccurrence"
        )
    }

    func testSilenceIsScopedToSingleOccurrence() {
        let service = CalendarService(eventStore: EKEventStore())
        let today = Date()
        let tomorrow = today.addingTimeInterval(86_400)

        service.silenceOccurrence(eventIdentifier: "standup", startDate: today)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "standup", startDate: today),
            "Today's occurrence should be silenced"
        )
        XCTAssertFalse(
            service.isOccurrenceSilenced(eventIdentifier: "standup", startDate: tomorrow),
            "Tomorrow's occurrence of the same recurring event should NOT be silenced"
        )
    }

    func testPruneRemovesPastOccurrences() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7_200)

        service.silenceOccurrence(eventIdentifier: "old-event", startDate: twoHoursAgo)
        service.pruneSilencedOccurrences(referenceDate: now)

        XCTAssertFalse(
            service.isOccurrenceSilenced(eventIdentifier: "old-event", startDate: twoHoursAgo),
            "Occurrence more than an hour past should be pruned"
        )
    }

    func testPruneKeepsUpcomingOccurrences() {
        let service = CalendarService(eventStore: EKEventStore())
        let now = Date()
        let tenMinutesAway = now.addingTimeInterval(600)

        service.silenceOccurrence(eventIdentifier: "soon-event", startDate: tenMinutesAway)
        service.pruneSilencedOccurrences(referenceDate: now)

        XCTAssertTrue(
            service.isOccurrenceSilenced(eventIdentifier: "soon-event", startDate: tenMinutesAway),
            "Upcoming silenced occurrence should survive pruning"
        )
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/CalendarServiceTests`
Expected: FAIL to compile — `SilencedOccurrence`, `silenceOccurrence`, `isOccurrenceSilenced`, and `pruneSilencedOccurrences` do not exist yet.

- [ ] **Step 3: Add the `SilencedOccurrence` type**

In `Sources/Services/CalendarService.swift`, add this struct at file scope immediately after the closing brace of `enum AlertType` (before `final class CalendarService`):

```swift
/// Identifies one occurrence of an event, so that silencing today's instance
/// of a recurring event does not silence tomorrow's (occurrences share an
/// eventIdentifier but differ by startDate).
struct SilencedOccurrence: Hashable {
    let eventIdentifier: String
    let startDate: Date
}
```

- [ ] **Step 4: Add the silence store and operations**

In `Sources/Services/CalendarService.swift`, add the store property immediately after the existing `private var notifiedEvents` line:

```swift
    private var silencedOccurrences: Set<SilencedOccurrence> = []
```

Then add these methods inside the class, immediately after the `stopMonitoring()` method:

```swift
    /// Suppress all remaining alerts for this event's occurrence.
    func silence(_ event: EKEvent) {
        guard let identifier = event.eventIdentifier else { return }
        silenceOccurrence(eventIdentifier: identifier, startDate: event.startDate)
    }

    func silenceOccurrence(eventIdentifier: String, startDate: Date) {
        silencedOccurrences.insert(SilencedOccurrence(eventIdentifier: eventIdentifier, startDate: startDate))
    }

    func isOccurrenceSilenced(eventIdentifier: String, startDate: Date) -> Bool {
        silencedOccurrences.contains(SilencedOccurrence(eventIdentifier: eventIdentifier, startDate: startDate))
    }

    /// Drop silenced occurrences whose start time is more than an hour past.
    func pruneSilencedOccurrences(referenceDate: Date = Date()) {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -1, to: referenceDate) ?? referenceDate
        silencedOccurrences = silencedOccurrences.filter { $0.startDate > cutoff }
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/CalendarServiceTests`
Expected: PASS — all `CalendarServiceTests` tests, including the five new ones.

- [ ] **Step 6: Commit**

```bash
git add Sources/Services/CalendarService.swift Tests/CalendarServiceTests.swift
git commit -m "feat: add per-occurrence silence tracking to CalendarService"
```

---

## Task 3: Skip silenced occurrences during the calendar scan

Wire the suppression state into the scan loop so silenced occurrences fire no further alerts, and prune stale entries each scan. This is glue between Task 2's tested logic and the existing scan; it is verified by build + the existing suite (the scan loop is not unit-tested in this codebase because it requires a live, populated `EKEventStore`).

**Files:**
- Modify: `Sources/Services/CalendarService.swift` (method `scanCalendars`)

- [ ] **Step 1: Skip silenced occurrences in the scan loop**

In `scanCalendars`, the per-event loop currently begins:

```swift
        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
```

Insert the silence check so it reads:

```swift
        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            // Skip occurrences the user silenced from the alarm modal.
            if isOccurrenceSilenced(eventIdentifier: eventID, startDate: event.startDate) { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
```

- [ ] **Step 2: Prune stale silenced occurrences each scan**

At the end of `scanCalendars`, the last line is `cleanupOldEventIDs()`. Change it to:

```swift
        cleanupOldEventIDs()
        pruneSilencedOccurrences()
```

- [ ] **Step 3: Build and run the full suite to verify no regressions**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'`
Expected: PASS — the project builds and the existing suite stays green.

- [ ] **Step 4: Commit**

```bash
git add Sources/Services/CalendarService.swift
git commit -m "feat: skip silenced occurrences during calendar scan"
```

---

## Task 4: Add localized "Silence" strings for all 28 locales

Add `alert.button.silence` (the button label) and `accessibility.alert.silenceButton` (the VoiceOver label) to every `Localizable.strings` file, and register them in `LocalizationTests`. Adding `alert.button.silence` to the per-language `criticalKeys` list makes the test suite verify that all 28 translations were actually added.

This task comes before the modal UI task because `AlertWindowController` will look up `alert.button.silence`, and its button test matches the resolved English title "Silence".

**Files:**
- Modify: `Tests/LocalizationTests.swift`
- Modify: all 28 `Sources/Resources/*.lproj/Localizable.strings` files

- [ ] **Step 1: Register the new keys in LocalizationTests**

In `Tests/LocalizationTests.swift`, in the `allKeys` array, change the "Alert Window" group's last line from:

```swift
        "alert.untitledEvent", "alert.button.dismiss", "alert.button.openEvent",
        "alert.button.join",
```

to:

```swift
        "alert.untitledEvent", "alert.button.dismiss", "alert.button.openEvent",
        "alert.button.join", "alert.button.silence",
```

In the same array, change the "Accessibility Labels - Alert Window" group from:

```swift
        // Accessibility Labels - Alert Window
        "accessibility.alert.dismissButton", "accessibility.alert.openEventButton",
        "accessibility.alert.joinButton", "accessibility.alert.joinButtonUnavailable",
        "accessibility.alert.joinLink",
```

to:

```swift
        // Accessibility Labels - Alert Window
        "accessibility.alert.dismissButton", "accessibility.alert.openEventButton",
        "accessibility.alert.joinButton", "accessibility.alert.joinButtonUnavailable",
        "accessibility.alert.joinLink", "accessibility.alert.silenceButton",
```

Update the count assertion in `testAllKeysCount` from:

```swift
        XCTAssertEqual(Self.allKeys.count, 92, "Should have 92 localization keys defined")
```

to:

```swift
        XCTAssertEqual(Self.allKeys.count, 94, "Should have 94 localization keys defined")
```

In `testLanguageHasRequiredKeys`, change the `criticalKeys` array from:

```swift
        let criticalKeys = [
            "menu.about", "menu.preferences", "menu.quit",
            "preferences.button.ok", "alert.button.dismiss"
        ]
```

to:

```swift
        let criticalKeys = [
            "menu.about", "menu.preferences", "menu.quit",
            "preferences.button.ok", "alert.button.dismiss", "alert.button.silence"
        ]
```

- [ ] **Step 2: Run LocalizationTests to verify they fail**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/LocalizationTests`
Expected: FAIL — `testEnglishHasAllKeys` fails (English file lacks the two keys) and `testLanguageHasRequiredKeys` fails (no language has `alert.button.silence`). `testAllKeysCount` passes.

- [ ] **Step 3: Add the keys to the English file**

In `Sources/Resources/en.lproj/Localizable.strings`, add this line immediately after the `"alert.button.join" = "Join Meeting";` line:

```
"alert.button.silence" = "Silence";
```

And add this line immediately after the `"accessibility.alert.joinButtonUnavailable" = ...;` line:

```
"accessibility.alert.silenceButton" = "Silence remaining alerts for this event";
```

- [ ] **Step 4: Run testEnglishHasAllKeys to verify it passes**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/LocalizationTests/testEnglishHasAllKeys`
Expected: PASS.

- [ ] **Step 5: Add the keys to the other 27 locale files**

For each language file `Sources/Resources/<code>.lproj/Localizable.strings`, add two lines using that language's row from the table below:

```
"alert.button.silence" = "<button label>";
"accessibility.alert.silenceButton" = "<accessibility label>";
```

`.strings` files are unordered key/value pairs, so placement does not affect behavior — but for tidiness add `alert.button.silence` next to the existing `alert.button.join` line and `accessibility.alert.silenceButton` next to `accessibility.alert.joinButtonUnavailable`.

| Code | `alert.button.silence` | `accessibility.alert.silenceButton` |
|------|------------------------|-------------------------------------|
| es | Silenciar | Silenciar las alertas restantes de este evento |
| fr | Mettre en sourdine | Mettre en sourdine les alertes restantes de cet événement |
| de | Stummschalten | Verbleibende Hinweise für dieses Ereignis stummschalten |
| it | Silenzia | Silenzia gli avvisi rimanenti per questo evento |
| pt | Silenciar | Silenciar os alertas restantes deste evento |
| nl | Dempen | Resterende meldingen voor dit evenement dempen |
| ja | 消音 | このイベントの残りのアラートを消音 |
| zh-Hans | 静音 | 静音此活动的剩余提醒 |
| ko | 음소거 | 이 이벤트의 남은 알림 음소거 |
| sw | Nyamazisha | Nyamazisha arifa zilizosalia za tukio hili |
| tr | Sustur | Bu etkinliğin kalan uyarılarını sustur |
| el | Σίγαση | Σίγαση των υπόλοιπων ειδοποιήσεων για αυτό το συμβάν |
| ru | Заглушить | Заглушить оставшиеся напоминания для этого события |
| pl | Wycisz | Wycisz pozostałe alerty dla tego wydarzenia |
| uk | Заглушити | Заглушити решту сповіщень для цієї події |
| cs | Ztlumit | Ztlumit zbývající upozornění pro tuto událost |
| sk | Stlmiť | Stlmiť zostávajúce upozornenia pre túto udalosť |
| sr | Утишај | Утишај преостала обавештења за овај догађај |
| hr | Utišaj | Utišaj preostale obavijesti za ovaj događaj |
| bg | Заглуши | Заглуши останалите известия за това събитие |
| vi | Tắt tiếng | Tắt tiếng các cảnh báo còn lại cho sự kiện này |
| th | ปิดเสียง | ปิดเสียงการแจ้งเตือนที่เหลือสำหรับกิจกรรมนี้ |
| id | Bisukan | Bisukan peringatan yang tersisa untuk acara ini |
| ms | Senyapkan | Senyapkan amaran yang tinggal untuk acara ini |
| fil | Patahimikin | Patahimikin ang natitirang mga alerto para sa kaganapang ito |
| zh-Hant | 靜音 | 靜音此活動的剩餘提醒 |
| ar | كتم | كتم التنبيهات المتبقية لهذا الحدث |

- [ ] **Step 6: Run the full LocalizationTests to verify they pass**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/LocalizationTests`
Expected: PASS — all `LocalizationTests`, including `testEnglishHasAllKeys`, `testAllKeysCount`, and `testLanguageHasRequiredKeys`.

- [ ] **Step 7: Commit**

```bash
git add Tests/LocalizationTests.swift Sources/Resources
git commit -m "i18n: add Silence button strings for all 28 locales"
```

---

## Task 5: Add the Silence button to the alarm modal

Widen the modal to 580pt, add the fourth button, and route its action through a new `onSilence` closure. The Silence button is always enabled; at every alert stage it stops the sound, calls `onSilence`, and closes the window.

**Files:**
- Modify: `Sources/Views/AlertWindowController.swift`
- Test: `Tests/AlertWindowTests.swift`

- [ ] **Step 1: Write the failing tests**

In `Tests/AlertWindowTests.swift`, update `testAlertWindowHasCorrectSize` — change the width assertion from `500` to `580`:

```swift
    @MainActor
    func testAlertWindowHasCorrectSize() {
        let controller = AlertWindowController(event: mockEvent)

        let frame = controller.window?.frame ?? .zero

        // Width should be exactly 580
        XCTAssertEqual(frame.width, 580, "Window width should be 580")
        // Height includes title bar, so it will be greater than content height of 220
        XCTAssertGreaterThanOrEqual(frame.height, 220, "Window height should be at least 220")
    }
```

Then add these two tests immediately before the `// MARK: - Audio Tests` line:

```swift
    @MainActor
    func testAlertWindowContainsSilenceButton() {
        let controller = AlertWindowController(event: mockEvent)

        let contentView = controller.window?.contentView
        let silenceButton = findButton(in: contentView, withTitle: "Silence")

        XCTAssertNotNil(silenceButton, "Window should contain a Silence button")
    }

    @MainActor
    func testSilenceButtonInvokesOnSilenceAndCloses() {
        var silencedEvent: EKEvent?
        let controller = AlertWindowController(event: mockEvent, onSilence: { event in
            silencedEvent = event
        })
        controller.showWindow(nil)

        let silenceButton = findButton(in: controller.window?.contentView, withTitle: "Silence")
        silenceButton?.performClick(nil)

        XCTAssertTrue(silencedEvent === mockEvent, "Silence should invoke onSilence with the event")
        XCTAssertFalse(controller.window?.isVisible ?? true, "Window should close after Silence")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests`
Expected: FAIL — `testSilenceButtonInvokesOnSilenceAndCloses` fails to compile (no `onSilence:` parameter); `testAlertWindowContainsSilenceButton` and `testAlertWindowHasCorrectSize` fail on assertions.

- [ ] **Step 3: Add the `onSilence` property and init parameter**

In `Sources/Views/AlertWindowController.swift`, the class currently opens:

```swift
final class AlertWindowController: NSWindowController {
    private let event: EKEvent
    private let alertType: AlertType
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?
    private var joinURL: URL?

    init(event: EKEvent, alertType: AlertType = .warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0)) {
        self.event = event
        self.alertType = alertType

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 220),
```

Replace that span with:

```swift
final class AlertWindowController: NSWindowController {
    private let event: EKEvent
    private let alertType: AlertType
    private let onSilence: ((EKEvent) -> Void)?
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?
    private var joinURL: URL?

    init(
        event: EKEvent,
        alertType: AlertType = .warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0),
        onSilence: ((EKEvent) -> Void)? = nil
    ) {
        self.event = event
        self.alertType = alertType
        self.onSilence = onSilence

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 220),
```

- [ ] **Step 4: Widen the content view and detail column**

In `setupContent()`, change the content view frame from:

```swift
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 220))
```

to:

```swift
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 220))
```

And change the detail-column width from:

```swift
        let rightWidth: CGFloat = 320
```

to:

```swift
        let rightWidth: CGFloat = 400
```

- [ ] **Step 5: Replace the three-button block with four buttons**

In `setupContent()`, replace this entire block:

```swift
        // Buttons - always show all three
        let dismissButton = NSButton(title: NSLocalizedString("alert.button.dismiss", comment: "Dismiss button"), target: self, action: #selector(dismissAlert))
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}" // Escape key
        dismissButton.frame = NSRect(x: 390, y: 15, width: 90, height: 32)
        dismissButton.setAccessibilityIdentifier("dismissButton")
        dismissButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.dismissButton", comment: "Dismiss alert"))
        contentView.addSubview(dismissButton)

        let openEventButton = NSButton(title: NSLocalizedString("alert.button.openEvent", comment: "Open Calendar button"), target: self, action: #selector(openEvent))
        openEventButton.bezelStyle = .rounded
        openEventButton.frame = NSRect(x: 275, y: 15, width: 105, height: 32)
        openEventButton.setAccessibilityIdentifier("openEventButton")
        openEventButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.openEventButton", comment: "Open the Calendar app"))
        contentView.addSubview(openEventButton)

        let joinButton = NSButton(title: NSLocalizedString("alert.button.join", comment: "Join button"), target: self, action: #selector(joinMeeting))
        joinButton.bezelStyle = .rounded
        joinButton.frame = NSRect(x: 160, y: 15, width: 105, height: 32)
        joinButton.setAccessibilityIdentifier("joinMeetingButton")
        joinButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.joinButton", comment: "Join video meeting"))
        contentView.addSubview(joinButton)
```

with this block (four equal-width buttons evenly spaced across the 580pt content width):

```swift
        // Buttons - bottom row of four, evenly spaced across the content width
        let buttonY: CGFloat = 15
        let buttonWidth: CGFloat = 126
        let buttonHeight: CGFloat = 32

        let joinButton = NSButton(title: NSLocalizedString("alert.button.join", comment: "Join button"), target: self, action: #selector(joinMeeting))
        joinButton.bezelStyle = .rounded
        joinButton.frame = NSRect(x: 20, y: buttonY, width: buttonWidth, height: buttonHeight)
        joinButton.setAccessibilityIdentifier("joinMeetingButton")
        joinButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.joinButton", comment: "Join video meeting"))
        contentView.addSubview(joinButton)

        let openEventButton = NSButton(title: NSLocalizedString("alert.button.openEvent", comment: "Open Calendar button"), target: self, action: #selector(openEvent))
        openEventButton.bezelStyle = .rounded
        openEventButton.frame = NSRect(x: 158, y: buttonY, width: buttonWidth, height: buttonHeight)
        openEventButton.setAccessibilityIdentifier("openEventButton")
        openEventButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.openEventButton", comment: "Open the Calendar app"))
        contentView.addSubview(openEventButton)

        let silenceButton = NSButton(title: NSLocalizedString("alert.button.silence", comment: "Silence button"), target: self, action: #selector(silenceAlert))
        silenceButton.bezelStyle = .rounded
        silenceButton.frame = NSRect(x: 296, y: buttonY, width: buttonWidth, height: buttonHeight)
        silenceButton.setAccessibilityIdentifier("silenceButton")
        silenceButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.silenceButton", comment: "Silence remaining alerts for this event"))
        contentView.addSubview(silenceButton)

        let dismissButton = NSButton(title: NSLocalizedString("alert.button.dismiss", comment: "Dismiss button"), target: self, action: #selector(dismissAlert))
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}" // Escape key
        dismissButton.frame = NSRect(x: 434, y: buttonY, width: buttonWidth, height: buttonHeight)
        dismissButton.setAccessibilityIdentifier("dismissButton")
        dismissButton.setAccessibilityLabel(NSLocalizedString("accessibility.alert.dismissButton", comment: "Dismiss alert"))
        contentView.addSubview(dismissButton)
```

The `joinURL`-based key-equivalent block immediately below (which references `joinButton` and `openEventButton`) is unchanged and still compiles — both variables remain in scope.

- [ ] **Step 6: Add the `silenceAlert` action**

In `Sources/Views/AlertWindowController.swift`, add this method immediately after the existing `dismissAlert()` method:

```swift
    @objc private func silenceAlert() {
        stopAlertSound()
        onSilence?(event)
        close()
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests`
Expected: PASS — all `AlertWindowTests`, including the new Silence-button tests and the updated size test.

- [ ] **Step 8: Commit**

```bash
git add Sources/Views/AlertWindowController.swift Tests/AlertWindowTests.swift
git commit -m "feat: add Silence button to the alarm modal"
```

---

## Task 6: Wire the Silence button to CalendarService

Connect the modal's `onSilence` closure to `CalendarService.silence(_:)` so a click actually suppresses the occurrence. This is a one-call-site change, verified by build + full suite.

**Files:**
- Modify: `Sources/App/AppDelegate.swift` (method `showEventAlert`)

- [ ] **Step 1: Pass the `onSilence` closure when creating the modal**

In `AppDelegate.swift`, replace the `showEventAlert` method:

```swift
    private func showEventAlert(event: EKEvent, alertType: AlertType) {
        DispatchQueue.main.async { [weak self] in
            self?.alertWindowController?.close()
            self?.alertWindowController = AlertWindowController(event: event, alertType: alertType)
            self?.alertWindowController?.showWindow(nil)
        }
    }
```

with:

```swift
    private func showEventAlert(event: EKEvent, alertType: AlertType) {
        DispatchQueue.main.async { [weak self] in
            self?.alertWindowController?.close()
            self?.alertWindowController = AlertWindowController(
                event: event,
                alertType: alertType,
                onSilence: { [weak self] silencedEvent in
                    self?.calendarService?.silence(silencedEvent)
                }
            )
            self?.alertWindowController?.showWindow(nil)
        }
    }
```

- [ ] **Step 2: Build and run the full suite to verify no regressions**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'`
Expected: PASS — the project builds and the entire suite is green.

- [ ] **Step 3: Commit**

```bash
git add Sources/App/AppDelegate.swift
git commit -m "feat: wire Silence button to CalendarService"
```

---

## Task 7: Final verification

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'`
Expected: PASS — every test, with no skips or failures.

- [ ] **Step 2: Build the Release configuration**

Run: `xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Release build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Manual smoke check (optional but recommended)**

Launch the app, let an alert fire (or trigger one with a near-future calendar event), and confirm:
- The modal is wider and shows four buttons: Join Meeting · Open Calendar · Silence · Dismiss.
- Clicking **Silence** stops the sound and closes the modal.
- The silenced event produces no further alerts (e.g. silence at the 5-minute warning → no 1-minute warning, no event-starting alert).
- A different event still alerts normally.

---

## Self-Review Notes

- **Spec coverage:** Per-occurrence keying (Task 2 `SilencedOccurrence`), scan suppression (Task 3), in-memory-only with pruning (Tasks 2–3), 580pt modal + 4th button (Task 5), `onSilence` wiring (Tasks 5–6), 28-locale translations (Task 4), stale-test fix as a standalone first commit (Task 1) — all spec sections map to tasks.
- **Type consistency:** `SilencedOccurrence(eventIdentifier:startDate:)`, `silence(_:)`, `silenceOccurrence(eventIdentifier:startDate:)`, `isOccurrenceSilenced(eventIdentifier:startDate:)`, `pruneSilencedOccurrences(referenceDate:)`, and `onSilence: ((EKEvent) -> Void)?` are named identically everywhere they appear.
- **Edge cases:** Final-alert behavior needs no special-casing — `silenceAlert()` runs the same path at every stage; recording a silence for an already-started event is a harmless no-op pruned within the hour.
