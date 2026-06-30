# Silence Fix, Occurrence-Aware Scan, Working Hours, and Title Filters — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Silence button and recurring-event handling by making the calendar scan occurrence-aware; always ignore all-day events; add a toggleable working-hours window (which may wrap past midnight) gated on event start time; and add a configurable list of regex title patterns whose events never alert.

**Architecture:** Three pure, unit-testable value types — `OccurrenceKey` (stable identifier + whole-second-normalized start), `WorkingHours` (wrapping window + weekday set), `TitleIgnoreList` (case-insensitive regex matcher) — drive a single `CalendarService.shouldEvaluate(...)` decision. The scan loop is a thin caller; both tracking maps key on `OccurrenceKey`; time-based pruning replaces the event-store re-query. A new "Filters" tab hosts working hours and title patterns.

**Tech Stack:** Swift, AppKit, EventKit, `os.Logger`, XCTest, `xcodebuild`.

**Conventions for this plan:**
- New types go inside existing files (`CalendarService.swift`, `Preferences.swift`) and new tests inside existing test files. The Xcode project uses explicit file references, so this avoids `.xcodeproj` edits.
- Build the pure models (Tasks 1–3) before the service rewrite (Task 4) so the tree compiles in task order.
- Logic-only test command (safe — no UI):
  ```bash
  xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' \
    -only-testing:KlaxonTests/CalendarServiceTests \
    -only-testing:KlaxonTests/PreferencesTests
  ```
- Build command (safe — no UI): `xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Debug build`
- Window-showing tests (`AlertWindowTests`, `PreferencesWindowControllerTests`) pop blocking modals — DO NOT run them without asking the user first. They run last (Task 7).
- Prefix git commands with `gh auth switch --user mlwelles >/dev/null 2>&1 &&`.

**File map:**
- Modify `Sources/Services/CalendarService.swift` — add `OccurrenceKey`; re-key both maps; helpers; `shouldEvaluate`; diagnostics; pruning; scan rewrite.
- Modify `Sources/Models/Preferences.swift` — add `WorkingHours` and `TitleIgnoreList`; keys + properties.
- Modify `Sources/Views/PreferencesWindowController.swift` — add the "Filters" tab + load/save wiring.
- Modify `Tests/CalendarServiceTests.swift` — `OccurrenceKey`, occurrence-independence, `shouldEvaluate`, pruning tests; update one existing test.
- Modify `Tests/PreferencesTests.swift` — `WorkingHours.allows`, `TitleIgnoreList.matches`/`parse`, persistence tests.
- Modify all 28 `Sources/Resources/*.lproj/Localizable.strings` — Filters-tab strings.

---

## Task 1: `OccurrenceKey` value type

**Files:**
- Modify: `Sources/Services/CalendarService.swift` (replace `SilencedOccurrence`; add `import os`)
- Test: `Tests/CalendarServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/CalendarServiceTests.swift` inside `final class CalendarServiceTests`:

```swift
// MARK: - OccurrenceKey Tests

func testOccurrenceKeyIgnoresSubSecondDrift() {
    let base = Date(timeIntervalSinceReferenceDate: 1_000_000.0)
    let drifted = Date(timeIntervalSinceReferenceDate: 1_000_000.4)
    let a = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: base)
    let b = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: drifted)
    XCTAssertEqual(a, b, "Sub-second drift must resolve to the same key")
}

func testOccurrenceKeyDistinguishesDifferentMinutes() {
    let t1 = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let t2 = t1.addingTimeInterval(60)
    let a = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: t1)
    let b = OccurrenceKey(eventIdentifier: "e", externalIdentifier: nil, title: "T", startDate: t2)
    XCTAssertNotEqual(a, b, "Occurrences a minute apart must differ")
}

func testOccurrenceKeyPrefersEventIdentifier() {
    let key = OccurrenceKey(eventIdentifier: "evt", externalIdentifier: "ext", title: "T", startDate: Date())
    XCTAssertEqual(key.identifier, "evt")
}

func testOccurrenceKeyFallsBackToExternalIdentifier() {
    let key = OccurrenceKey(eventIdentifier: nil, externalIdentifier: "ext-1", title: "T", startDate: Date())
    XCTAssertEqual(key.identifier, "ext-1", "Nil eventIdentifier falls back to externalIdentifier")
}

func testOccurrenceKeyFallsBackToTitle() {
    let key = OccurrenceKey(eventIdentifier: nil, externalIdentifier: nil, title: "Standup", startDate: Date())
    XCTAssertEqual(key.identifier, "Standup", "Both identifiers nil falls back to title")
}

func testOccurrenceKeyEmptyStringsTreatedAsMissing() {
    let key = OccurrenceKey(eventIdentifier: "", externalIdentifier: "", title: "Standup", startDate: Date())
    XCTAssertEqual(key.identifier, "Standup", "Empty strings are treated as missing")
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/CalendarServiceTests 2>&1 | tail -20
```
Expected: compile failure — `cannot find 'OccurrenceKey' in scope`.

- [ ] **Step 3: Implement `OccurrenceKey`**

In `Sources/Services/CalendarService.swift`, add `import os` below `import Foundation`. Replace the existing `SilencedOccurrence` struct with:

```swift
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
```

- [ ] **Step 4: Update the existing equality test**

In `Tests/CalendarServiceTests.swift`, replace `testSilencedOccurrenceEquality` with:

```swift
func testOccurrenceKeyEquality() {
    let start = Date()
    let a = OccurrenceKey(identifier: "e", startDate: start)
    let b = OccurrenceKey(identifier: "e", startDate: start)
    let c = OccurrenceKey(identifier: "e", startDate: start.addingTimeInterval(60))

    XCTAssertEqual(a, b, "Same identifier and start should be equal")
    XCTAssertNotEqual(a, c, "Different starts should not be equal")
}
```

> The file will not fully compile until Task 4 re-keys `silencedOccurrences`/`notifiedEvents`. Implement Tasks 1–4 before the first green test run; the commit at the end of Task 4 is the first compiling checkpoint. (Models in Tasks 2–3 compile independently and are committed there.)

---

## Task 2: `TitleIgnoreList` model + `ignoredTitlePatterns` preference

**Files:**
- Modify: `Sources/Models/Preferences.swift`
- Test: `Tests/PreferencesTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/PreferencesTests.swift`:

```swift
// MARK: - TitleIgnoreList

func testTitleIgnoreMatchesCaseInsensitiveSubstring() {
    let list = TitleIgnoreList(patterns: ["OOTO"])
    XCTAssertTrue(list.matches("ooto - team offsite"), "Unanchored, case-insensitive substring matches")
}

func testTitleIgnoreAnchoredPatternMatchesExactly() {
    let list = TitleIgnoreList(patterns: ["^Busy$"])
    XCTAssertTrue(list.matches("Busy"))
    XCTAssertFalse(list.matches("Busy with client"), "Anchored pattern only matches the exact title")
}

func testTitleIgnoreMatchesAnyPattern() {
    let list = TitleIgnoreList(patterns: ["Unavailable", "OOTO"])
    XCTAssertTrue(list.matches("OOTO"))
    XCTAssertTrue(list.matches("Unavailable"))
    XCTAssertFalse(list.matches("Sprint planning"))
}

func testTitleIgnoreSkipsBlankPatterns() {
    let list = TitleIgnoreList(patterns: ["   ", ""])
    XCTAssertFalse(list.matches("Any meeting"), "Blank patterns must not match everything")
}

func testTitleIgnoreSkipsInvalidRegex() {
    let list = TitleIgnoreList(patterns: ["["]) // invalid regex
    XCTAssertFalse(list.matches("[ bracket meeting"), "Invalid regex is skipped, not fatal")
}

func testTitleIgnoreNilOrEmptyTitleNeverMatches() {
    let list = TitleIgnoreList(patterns: ["OOTO"])
    XCTAssertFalse(list.matches(nil))
    XCTAssertFalse(list.matches(""))
}

func testTitleIgnoreParseSplitsTrimsAndDropsEmpties() {
    let parsed = TitleIgnoreList.parse("OOTO\n  Unavailable  \n\n\t\nBusy")
    XCTAssertEqual(parsed, ["OOTO", "Unavailable", "Busy"])
}

func testIgnoredTitlePatternsPersistenceRoundTrip() {
    let suite = "IgnoreTest-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)

    XCTAssertEqual(prefs.ignoredTitlePatterns, [], "Default is empty")
    prefs.ignoredTitlePatterns = ["OOTO", "Unavailable"]
    XCTAssertEqual(Preferences(defaults: defaults).ignoredTitlePatterns, ["OOTO", "Unavailable"])
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/PreferencesTests 2>&1 | tail -20
```
Expected: compile failure — `cannot find 'TitleIgnoreList' in scope`.

- [ ] **Step 3: Implement `TitleIgnoreList`**

In `Sources/Models/Preferences.swift`, after the `AlertWarning` struct, add:

```swift
/// A list of regular-expression patterns. An event whose title matches any
/// pattern should never alert. Matching is case-insensitive and unanchored;
/// blank and invalid patterns are skipped (never matching everything, never
/// fatal).
struct TitleIgnoreList {
    let patterns: [String]

    func matches(_ title: String?) -> Bool {
        guard let title = title, !title.isEmpty else { return false }
        let range = NSRange(title.startIndex..., in: title)
        for raw in patterns {
            let pattern = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pattern.isEmpty else { continue }
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            if regex.firstMatch(in: title, options: [], range: range) != nil { return true }
        }
        return false
    }

    /// Split user-entered text (one pattern per line) into trimmed, non-empty patterns.
    static func parse(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
```

Add to the `Keys` enum:

```swift
static let ignoredTitlePatterns = "ignoredTitlePatterns"
```

Add the property (near `disabledCalendarIDs`):

```swift
/// Regex patterns; events whose title matches any pattern never alert.
var ignoredTitlePatterns: [String] {
    get { defaults.stringArray(forKey: Keys.ignoredTitlePatterns) ?? [] }
    set { defaults.set(newValue, forKey: Keys.ignoredTitlePatterns) }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/PreferencesTests 2>&1 | tail -20
```
Expected: all `PreferencesTests` PASS.

- [ ] **Step 5: Commit**

```bash
gh auth switch --user mlwelles >/dev/null 2>&1 && \
git add Sources/Models/Preferences.swift Tests/PreferencesTests.swift && \
git commit -m "feat: add TitleIgnoreList model and ignoredTitlePatterns preference"
```

---

## Task 3: `WorkingHours` model + `workingHours` preference

**Files:**
- Modify: `Sources/Models/Preferences.swift`
- Test: `Tests/PreferencesTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/PreferencesTests.swift`:

```swift
// MARK: - WorkingHours

/// Build a date at a known weekday/time. 2026-06-28 is a Sunday (weekday 1);
/// adding (weekday-1) days yields the requested weekday.
private func whDate(weekday: Int, hour: Int, minute: Int) -> Date {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 28 + (weekday - 1)
    comps.hour = hour; comps.minute = minute
    let date = Calendar.current.date(from: comps)!
    XCTAssertEqual(Calendar.current.component(.weekday, from: date), weekday, "date helper weekday sanity")
    return date
}

func testWorkingHoursDisabledAlwaysAllows() {
    let wh = WorkingHours(enabled: false, startMinutes: 540, endMinutes: 1020, activeDays: [2])
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 1, hour: 3, minute: 0)))
}

func testWorkingHoursDaytimeInWindow() {
    let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 10, minute: 0)))
}

func testWorkingHoursDaytimeBeforeAndAfterSuppress() {
    let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
    XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 8, minute: 30)))
    XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 17, minute: 30)))
}

func testWorkingHoursDaytimeBoundariesInclusive() {
    let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2])
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 9, minute: 0)), "start inclusive")
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 17, minute: 0)), "end inclusive")
}

func testWorkingHoursInactiveDaySuppresses() {
    let wh = WorkingHours(enabled: true, startMinutes: 540, endMinutes: 1020, activeDays: [2,3,4,5,6])
    XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 1, hour: 10, minute: 0)), "Sunday inactive")
}

func testWorkingHoursWrappingNightShift() {
    // 23:00–07:00 night shift on Monday.
    let wh = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2])
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 23, minute: 30)), "after start, before midnight")
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 2, minute: 0)), "after midnight, before end")
    XCTAssertFalse(wh.allows(eventStart: whDate(weekday: 2, hour: 12, minute: 0)), "midday outside")
}

func testWorkingHoursWrappingBoundariesInclusive() {
    let wh = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2])
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 23, minute: 0)), "start inclusive")
    XCTAssertTrue(wh.allows(eventStart: whDate(weekday: 2, hour: 7, minute: 0)), "end inclusive")
}

func testWorkingHoursPersistenceRoundTrip() {
    let suite = "WorkingHoursTest-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)

    XCTAssertFalse(prefs.workingHours.enabled, "Default disabled")

    prefs.workingHours = WorkingHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60, activeDays: [2, 4])
    let reloaded = Preferences(defaults: defaults).workingHours
    XCTAssertEqual(reloaded.enabled, true)
    XCTAssertEqual(reloaded.startMinutes, 23 * 60)
    XCTAssertEqual(reloaded.endMinutes, 7 * 60)
    XCTAssertEqual(reloaded.activeDays, [2, 4])
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/PreferencesTests 2>&1 | tail -20
```
Expected: compile failure — `cannot find 'WorkingHours' in scope`.

- [ ] **Step 3: Implement `WorkingHours`**

In `Sources/Models/Preferences.swift`, after the `TitleIgnoreList` struct, add:

```swift
/// A daily window (and active weekdays) during which alerts are allowed. Times
/// are minutes since midnight; weekdays use Calendar's convention (1 = Sunday …
/// 7 = Saturday). The window may wrap past midnight (a night shift).
struct WorkingHours: Codable, Equatable {
    var enabled: Bool
    var startMinutes: Int
    var endMinutes: Int
    var activeDays: Set<Int>

    static let `default` = WorkingHours(
        enabled: false,
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        activeDays: [2, 3, 4, 5, 6]   // Mon–Fri
    )

    /// True if alerts are allowed for an event starting at `date`. Disabled hours
    /// always allow. Otherwise the event's start weekday must be active and its
    /// minute-of-day within the window. A "from" later than its "to" (e.g.
    /// 23:00–07:00) wraps past midnight.
    func allows(eventStart date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return true }
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else {
            return true
        }
        guard activeDays.contains(weekday) else { return false }
        let minuteOfDay = hour * 60 + minute
        if startMinutes <= endMinutes {
            return minuteOfDay >= startMinutes && minuteOfDay <= endMinutes
        } else {
            return minuteOfDay >= startMinutes || minuteOfDay <= endMinutes
        }
    }
}
```

Add to the `Keys` enum:

```swift
static let workingHours = "workingHours"
```

Add the property (near `warnings`):

```swift
/// Daily window during which alerts are shown.
var workingHours: WorkingHours {
    get {
        guard let data = defaults.data(forKey: Keys.workingHours),
              let decoded = try? JSONDecoder().decode(WorkingHours.self, from: data) else {
            return .default
        }
        return decoded
    }
    set {
        if let encoded = try? JSONEncoder().encode(newValue) {
            defaults.set(encoded, forKey: Keys.workingHours)
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/PreferencesTests 2>&1 | tail -20
```
Expected: all `PreferencesTests` PASS.

- [ ] **Step 5: Commit**

```bash
gh auth switch --user mlwelles >/dev/null 2>&1 && \
git add Sources/Models/Preferences.swift Tests/PreferencesTests.swift && \
git commit -m "feat: add WorkingHours model with wrapping window and preference"
```

---

## Task 4: Re-key `CalendarService`; add gates, diagnostics, pruning, scan rewrite

**Files:**
- Modify: `Sources/Services/CalendarService.swift`
- Test: `Tests/CalendarServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/CalendarServiceTests.swift`:

```swift
// MARK: - Occurrence-aware scan helpers

private func allHours() -> WorkingHours {
    WorkingHours(enabled: false, startMinutes: 0, endMinutes: 1440, activeDays: [1,2,3,4,5,6,7])
}
private func noIgnore() -> TitleIgnoreList { TitleIgnoreList(patterns: []) }

func testSilenceIsPerOccurrenceViaKey() {
    let service = CalendarService(eventStore: EKEventStore())
    let today = OccurrenceKey(identifier: "standup", startDate: Date())
    let tomorrow = OccurrenceKey(identifier: "standup", startDate: Date().addingTimeInterval(86_400))

    service.silence(key: today)

    XCTAssertTrue(service.isSilenced(today))
    XCTAssertFalse(service.isSilenced(tomorrow), "Same-id next-day occurrence not silenced")
}

func testNotifiedStateIsPerOccurrence() {
    let service = CalendarService(eventStore: EKEventStore())
    let a = OccurrenceKey(identifier: "standup", startDate: Date())
    let b = OccurrenceKey(identifier: "standup", startDate: Date().addingTimeInterval(86_400))

    service.recordAlert(.eventStarting, for: a)

    XCTAssertTrue(service.wasAlertSent(.eventStarting, for: a))
    XCTAssertFalse(service.wasAlertSent(.eventStarting, for: b), "Occurrence B independent")
}

func testShouldEvaluateSkipsAllDay() {
    let service = CalendarService(eventStore: EKEventStore())
    let key = OccurrenceKey(identifier: "holiday", startDate: Date())
    XCTAssertFalse(service.shouldEvaluate(isAllDay: true, title: "Holiday", eventStart: Date(),
                                          key: key, workingHours: allHours(), ignoreList: noIgnore()))
}

func testShouldEvaluateSkipsIgnoredTitle() {
    let service = CalendarService(eventStore: EKEventStore())
    let key = OccurrenceKey(identifier: "ooto", startDate: Date())
    let ignore = TitleIgnoreList(patterns: ["OOTO"])
    XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "OOTO - dentist", eventStart: Date(),
                                          key: key, workingHours: allHours(), ignoreList: ignore))
}

func testShouldEvaluateSkipsOutOfWorkingHours() {
    let service = CalendarService(eventStore: EKEventStore())
    let key = OccurrenceKey(identifier: "mtg", startDate: Date())
    // No active days => always out of window when enabled.
    let none = WorkingHours(enabled: true, startMinutes: 0, endMinutes: 1440, activeDays: [])
    XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "Mtg", eventStart: Date(),
                                          key: key, workingHours: none, ignoreList: noIgnore()))
}

func testShouldEvaluateSkipsSilenced() {
    let service = CalendarService(eventStore: EKEventStore())
    let key = OccurrenceKey(identifier: "mtg", startDate: Date())
    service.silence(key: key)
    XCTAssertFalse(service.shouldEvaluate(isAllDay: false, title: "Mtg", eventStart: Date(),
                                          key: key, workingHours: allHours(), ignoreList: noIgnore()))
}

func testShouldEvaluateAllowsEligibleEvent() {
    let service = CalendarService(eventStore: EKEventStore())
    let key = OccurrenceKey(identifier: "mtg", startDate: Date())
    XCTAssertTrue(service.shouldEvaluate(isAllDay: false, title: "Sprint planning", eventStart: Date(),
                                         key: key, workingHours: allHours(), ignoreList: noIgnore()))
}

func testPruneRemovesPastNotifiedAndSilenced() {
    let service = CalendarService(eventStore: EKEventStore())
    let now = Date()
    let oldKey = OccurrenceKey(identifier: "old", startDate: now.addingTimeInterval(-7_200))
    service.recordAlert(.eventStarting, for: oldKey)
    service.silence(key: oldKey)

    service.pruneState(referenceDate: now)

    XCTAssertFalse(service.wasAlertSent(.eventStarting, for: oldKey))
    XCTAssertFalse(service.isSilenced(oldKey))
}

func testPruneKeepsRecentState() {
    let service = CalendarService(eventStore: EKEventStore())
    let now = Date()
    let recent = OccurrenceKey(identifier: "soon", startDate: now.addingTimeInterval(600))
    service.recordAlert(.eventStarting, for: recent)
    service.pruneState(referenceDate: now)
    XCTAssertTrue(service.wasAlertSent(.eventStarting, for: recent))
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/CalendarServiceTests 2>&1 | tail -25
```
Expected: compile failure — missing `silence(key:)`, `isSilenced(_:)`, `recordAlert`, `wasAlertSent`, `shouldEvaluate`, `pruneState`.

- [ ] **Step 3: Re-key state and add helpers**

In `Sources/Services/CalendarService.swift`, change the stored properties to:

```swift
private var notifiedEvents: [OccurrenceKey: Set<AlertType>] = [:]
private var silencedOccurrences: Set<OccurrenceKey> = []
private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mlwelles.klaxon", category: "scan")
```

Replace the existing `silence(_:)`, `silenceOccurrence(...)`, `isOccurrenceSilenced(...)`, and `pruneSilencedOccurrences(...)` with:

```swift
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
```

- [ ] **Step 4: Rewrite `scanCalendars` and delete `cleanupOldEventIDs`**

Replace the per-event loop and trailing cleanup in `scanCalendars()` with:

```swift
let prefs = Preferences.shared
let workingHours = prefs.workingHours
let ignoreList = TitleIgnoreList(patterns: prefs.ignoredTitlePatterns)

for event in events {
    let key = OccurrenceKey(event: event)
    guard shouldEvaluate(isAllDay: event.isAllDay, title: event.title, eventStart: event.startDate,
                         key: key, workingHours: workingHours, ignoreList: ignoreList) else { continue }

    let timeUntilStart = event.startDate.timeIntervalSince(now)

    for warning in prefs.warnings {
        let alertSeconds = TimeInterval(warning.minutesBefore * 60)
        let alertType = AlertType.warning(minutes: warning.minutesBefore, sound: warning.sound, soundDuration: warning.soundDuration)
        if timeUntilStart <= alertSeconds && timeUntilStart > alertSeconds - 30 && !wasAlertSent(alertType, for: key) {
            recordAlert(alertType, for: key)
            log.notice("Firing \(warning.minutesBefore, privacy: .public)-min warning sec=\(key.startSecond, privacy: .public)")
            onEventAlert?(event, alertType)
        }
    }

    if timeUntilStart <= 0 && timeUntilStart > -30 && !wasAlertSent(.eventStarting, for: key) {
        recordAlert(.eventStarting, for: key)
        log.notice("Firing event-starting sec=\(key.startSecond, privacy: .public)")
        onEventAlert?(event, .eventStarting)
    }
}

pruneState()
```

Delete the entire `private func cleanupOldEventIDs()` method and its call site (replaced by `pruneState()`).

> Note: the old `guard let eventID = event.eventIdentifier else { continue }` is gone — events without an identifier now get a title-based key instead of being skipped, so they too can be silenced and deduped.

- [ ] **Step 5: Run to verify it passes**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' \
  -only-testing:KlaxonTests/CalendarServiceTests \
  -only-testing:KlaxonTests/PreferencesTests 2>&1 | tail -25
```
Expected: both classes PASS, including legacy `testSilenceOccurrenceMarksItSilenced`, `testSilenceIsScopedToSingleOccurrence`, `testPruneRemovesPastOccurrences`, `testPruneKeepsUpcomingOccurrences`.

- [ ] **Step 6: Commit**

```bash
gh auth switch --user mlwelles >/dev/null 2>&1 && \
git add Sources/Services/CalendarService.swift Tests/CalendarServiceTests.swift && \
git commit -m "fix: make scan occurrence-aware; ignore all-day and title-matched events; gate by working hours"
```

---

## Task 5: "Filters" tab UI

**Files:**
- Modify: `Sources/Views/PreferencesWindowController.swift`

UI tests are window-showing and run last (Task 7). Build to verify compilation.

- [ ] **Step 1: Add `NSTextViewDelegate` conformance and stored properties**

Change the class declaration:

```swift
final class PreferencesWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
```

Add near the other control properties:

```swift
private var workingHoursEnabledCheckbox: NSButton!
private var startTimePicker: NSDatePicker!
private var endTimePicker: NSDatePicker!
private var weekdayCheckboxes: [NSButton] = []
private var ignoredPatternsTextView: NSTextView!
```

- [ ] **Step 2: Register the tab**

In `setupContent()`, after the `calendarTab` block and before the `otherTab` block, add:

```swift
let filtersTab = NSTabViewItem(identifier: "filters")
filtersTab.label = NSLocalizedString("preferences.tab.filters", comment: "Filters tab label")
filtersTab.view = createFiltersTabContent()
tabView.addTabViewItem(filtersTab)
```

- [ ] **Step 3: Build the tab content**

Add near `createOtherTabContent()`:

```swift
private func createFiltersTabContent() -> NSView {
    let tabContent = NSView()

    // --- Working Hours section ---
    let whHeader = createSectionHeader(NSLocalizedString("preferences.filters.workingHours.header", comment: "Working hours header"))
    tabContent.addSubview(whHeader)

    workingHoursEnabledCheckbox = createCheckbox(
        title: NSLocalizedString("preferences.filters.workingHours.enable", comment: "Enable working hours"),
        action: #selector(workingHoursChanged)
    )
    workingHoursEnabledCheckbox.setAccessibilityIdentifier("workingHoursEnabledCheckbox")
    tabContent.addSubview(workingHoursEnabledCheckbox)

    let fromLabel = createLabel(NSLocalizedString("preferences.filters.from", comment: "From label"))
    tabContent.addSubview(fromLabel)
    startTimePicker = makeTimePicker(identifier: "startTimePicker")
    tabContent.addSubview(startTimePicker)

    let toLabel = createLabel(NSLocalizedString("preferences.filters.to", comment: "to label"))
    tabContent.addSubview(toLabel)
    endTimePicker = makeTimePicker(identifier: "endTimePicker")
    tabContent.addSubview(endTimePicker)

    let daysLabel = createLabel(NSLocalizedString("preferences.filters.days", comment: "Days label"))
    tabContent.addSubview(daysLabel)

    let symbols = Calendar.current.shortWeekdaySymbols  // index 0 = Sunday = weekday 1
    let dayStack = NSStackView()
    dayStack.translatesAutoresizingMaskIntoConstraints = false
    dayStack.orientation = .horizontal
    dayStack.spacing = 8
    weekdayCheckboxes = (0..<7).map { index in
        let box = NSButton(checkboxWithTitle: symbols[index], target: self, action: #selector(workingHoursChanged))
        box.tag = index + 1
        box.setAccessibilityIdentifier("weekday\(index + 1)Checkbox")
        dayStack.addArrangedSubview(box)
        return box
    }
    tabContent.addSubview(dayStack)

    let whNote = createNoteLabel(NSLocalizedString("preferences.filters.workingHours.note", comment: "Working hours note"))
    whNote.lineBreakMode = .byWordWrapping
    whNote.maximumNumberOfLines = 0
    tabContent.addSubview(whNote)

    // --- Ignore-by-title section ---
    let titleHeader = createSectionHeader(NSLocalizedString("preferences.filters.titles.header", comment: "Ignore titles header"))
    tabContent.addSubview(titleHeader)

    let patternsScroll = NSScrollView()
    patternsScroll.translatesAutoresizingMaskIntoConstraints = false
    patternsScroll.hasVerticalScroller = true
    patternsScroll.borderType = .bezelBorder
    let textView = NSTextView()
    textView.isRichText = false
    textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.delegate = self
    textView.setAccessibilityIdentifier("ignoredPatternsTextView")
    patternsScroll.documentView = textView
    ignoredPatternsTextView = textView
    tabContent.addSubview(patternsScroll)

    let titleNote = createNoteLabel(NSLocalizedString("preferences.filters.titles.note", comment: "Ignore titles note"))
    titleNote.lineBreakMode = .byWordWrapping
    titleNote.maximumNumberOfLines = 0
    tabContent.addSubview(titleNote)

    let allDayNote = createNoteLabel(NSLocalizedString("preferences.filters.allDayNote", comment: "All-day always ignored note"))
    allDayNote.lineBreakMode = .byWordWrapping
    allDayNote.maximumNumberOfLines = 0
    tabContent.addSubview(allDayNote)

    NSLayoutConstraint.activate([
        whHeader.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
        whHeader.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

        workingHoursEnabledCheckbox.topAnchor.constraint(equalTo: whHeader.bottomAnchor, constant: 12),
        workingHoursEnabledCheckbox.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

        fromLabel.topAnchor.constraint(equalTo: workingHoursEnabledCheckbox.bottomAnchor, constant: 14),
        fromLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        startTimePicker.centerYAnchor.constraint(equalTo: fromLabel.centerYAnchor),
        startTimePicker.leadingAnchor.constraint(equalTo: fromLabel.trailingAnchor, constant: 8),
        toLabel.centerYAnchor.constraint(equalTo: fromLabel.centerYAnchor),
        toLabel.leadingAnchor.constraint(equalTo: startTimePicker.trailingAnchor, constant: 12),
        endTimePicker.centerYAnchor.constraint(equalTo: fromLabel.centerYAnchor),
        endTimePicker.leadingAnchor.constraint(equalTo: toLabel.trailingAnchor, constant: 8),

        daysLabel.topAnchor.constraint(equalTo: fromLabel.bottomAnchor, constant: 16),
        daysLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        dayStack.centerYAnchor.constraint(equalTo: daysLabel.centerYAnchor),
        dayStack.leadingAnchor.constraint(equalTo: daysLabel.trailingAnchor, constant: 8),

        whNote.topAnchor.constraint(equalTo: daysLabel.bottomAnchor, constant: 12),
        whNote.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        whNote.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),

        titleHeader.topAnchor.constraint(equalTo: whNote.bottomAnchor, constant: 20),
        titleHeader.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

        patternsScroll.topAnchor.constraint(equalTo: titleHeader.bottomAnchor, constant: 8),
        patternsScroll.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        patternsScroll.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
        patternsScroll.heightAnchor.constraint(equalToConstant: 100),

        titleNote.topAnchor.constraint(equalTo: patternsScroll.bottomAnchor, constant: 8),
        titleNote.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        titleNote.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),

        allDayNote.topAnchor.constraint(equalTo: titleNote.bottomAnchor, constant: 12),
        allDayNote.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        allDayNote.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
    ])

    return tabContent
}

private func makeTimePicker(identifier: String) -> NSDatePicker {
    let picker = NSDatePicker()
    picker.translatesAutoresizingMaskIntoConstraints = false
    picker.datePickerStyle = .textFieldAndStepper
    picker.datePickerElements = .hourMinute
    picker.target = self
    picker.action = #selector(workingHoursChanged)
    picker.setAccessibilityIdentifier(identifier)
    return picker
}
```

- [ ] **Step 4: Load state**

In `loadPreferences()`, before `// Load calendars`, add:

```swift
let wh = Preferences.shared.workingHours
workingHoursEnabledCheckbox.state = wh.enabled ? .on : .off
startTimePicker.dateValue = timeDate(fromMinutes: wh.startMinutes)
endTimePicker.dateValue = timeDate(fromMinutes: wh.endMinutes)
for box in weekdayCheckboxes {
    box.state = wh.activeDays.contains(box.tag) ? .on : .off
}
updateWorkingHoursControlsEnabled()

ignoredPatternsTextView.string = Preferences.shared.ignoredTitlePatterns.joined(separator: "\n")
```

- [ ] **Step 5: Add actions and helpers**

Add near the other `@objc` actions:

```swift
@objc private func workingHoursChanged() {
    let days = Set(weekdayCheckboxes.filter { $0.state == .on }.map { $0.tag })
    Preferences.shared.workingHours = WorkingHours(
        enabled: workingHoursEnabledCheckbox.state == .on,
        startMinutes: minutes(fromDate: startTimePicker.dateValue),
        endMinutes: minutes(fromDate: endTimePicker.dateValue),
        activeDays: days
    )
    updateWorkingHoursControlsEnabled()
}

private func updateWorkingHoursControlsEnabled() {
    let enabled = workingHoursEnabledCheckbox.state == .on
    startTimePicker.isEnabled = enabled
    endTimePicker.isEnabled = enabled
    weekdayCheckboxes.forEach { $0.isEnabled = enabled }
}

private func timeDate(fromMinutes minutes: Int) -> Date {
    var comps = DateComponents()
    comps.hour = minutes / 60
    comps.minute = minutes % 60
    return Calendar.current.date(from: comps) ?? Date()
}

private func minutes(fromDate date: Date) -> Int {
    let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
}

// NSTextViewDelegate: persist ignore patterns as the user edits.
func textDidChange(_ notification: Notification) {
    guard (notification.object as? NSTextView) === ignoredPatternsTextView else { return }
    Preferences.shared.ignoredTitlePatterns = TitleIgnoreList.parse(ignoredPatternsTextView.string)
}
```

Note: there is no "end after start" clamp — wrapping windows (night shifts) are valid.

- [ ] **Step 6: Build to verify compilation**

Run:
```bash
xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Debug build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
gh auth switch --user mlwelles >/dev/null 2>&1 && \
git add Sources/Views/PreferencesWindowController.swift && \
git commit -m "feat: add Filters tab for working hours and title ignore patterns"
```

---

## Task 6: Localization strings (28 locales)

**Files:**
- Modify: every `Sources/Resources/*.lproj/Localizable.strings`

- [ ] **Step 1: Add the English keys**

Append to `Sources/Resources/en.lproj/Localizable.strings`:

```
"preferences.tab.filters" = "Filters";
"preferences.filters.workingHours.header" = "Working Hours";
"preferences.filters.workingHours.enable" = "Only alert during working hours";
"preferences.filters.from" = "From";
"preferences.filters.to" = "to";
"preferences.filters.days" = "Days";
"preferences.filters.workingHours.note" = "Alerts fire only for events that start within this window on the selected days. A start time later than the end time is a window that crosses midnight (a night shift).";
"preferences.filters.titles.header" = "Ignore Events by Title";
"preferences.filters.titles.note" = "One pattern per line. Patterns are case-insensitive regular expressions matched anywhere in the title. Examples: Unavailable, OOTO";
"preferences.filters.allDayNote" = "All-day events (holidays, out-of-office, and similar) are always ignored.";
```

- [ ] **Step 2: Add translated keys to the remaining 27 locales**

For each `Sources/Resources/<locale>.lproj/Localizable.strings` (all except `en`), append the same ten keys with locale-appropriate translations, matching the quality of existing entries (use nearby `preferences.tab.*` / `preferences.general.header` translations as the tone reference). Where a confident translation is unavailable, use the English value rather than omitting the key (a missing key surfaces the raw key in the UI).

- [ ] **Step 3: Verify every locale has all ten keys**

Run:
```bash
for d in Sources/Resources/*.lproj; do \
  c=$(grep -c 'preferences\.filters\.\|preferences\.tab\.filters' "$d/Localizable.strings"); \
  echo "$c  $d"; \
done
```
Expected: every line begins with `10`.

- [ ] **Step 4: Confirm `LocalizationTests` pass**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/LocalizationTests 2>&1 | tail -15
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gh auth switch --user mlwelles >/dev/null 2>&1 && \
git add Sources/Resources && \
git commit -m "i18n: add Filters tab strings for all 28 locales"
```

---

## Task 7: Final verification

- [ ] **Step 1: Release build**

Run:
```bash
xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Release build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Full logic-test set**

Run:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' \
  -only-testing:KlaxonTests/CalendarServiceTests \
  -only-testing:KlaxonTests/PreferencesTests \
  -only-testing:KlaxonTests/CalendarFilteringTests \
  -only-testing:KlaxonTests/LocalizationTests \
  -only-testing:KlaxonTests/LoginItemServiceTests \
  -only-testing:KlaxonTests/CalendarAccessTests 2>&1 | tail -25
```
Expected: all PASS.

- [ ] **Step 3: STOP — ask the user before UI tests**

`AlertWindowTests` and `PreferencesWindowControllerTests` show windows (blocking modals). Ask the user for permission before running:
```bash
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' \
  -only-testing:KlaxonTests/AlertWindowTests \
  -only-testing:KlaxonTests/PreferencesWindowControllerTests 2>&1 | tail -25
```

- [ ] **Step 4: Manual smoke (optional, with user present)**

Open Preferences → Filters. Toggle working hours, set a daytime and a night-shift window, add an "OOTO" pattern. Confirm: an out-of-window event does not alert; an in-window one does; an event titled "OOTO ..." never alerts; an all-day event never alerts. Silence a warning and confirm later alerts for that occurrence stay suppressed (Console.app, subsystem = bundle id, category `scan`).

---

## Self-review notes

- **Spec coverage:** OccurrenceKey + fallback + normalization (Task 1); TitleIgnoreList + parse + preference (Task 2); WorkingHours wrapping + preference (Task 3); re-keyed maps, all-day filter, title + working-hours + silence gates, diagnostics, pruning, scan rewrite (Task 4); Filters tab UI (Task 5); i18n (Task 6); deferred UI tests (Task 7). Every spec section maps to a task.
- **Type consistency:** `OccurrenceKey(identifier:startSecond:)`, `(identifier:startDate:)`, `(eventIdentifier:externalIdentifier:title:startDate:)`, `(event:)`; `WorkingHours(enabled:startMinutes:endMinutes:activeDays:)` + `allows(eventStart:)`; `TitleIgnoreList(patterns:)` + `matches(_:)` + `parse(_:)`; service `silence(_:)`, `silence(key:)`, `isSilenced(_:)`, `wasAlertSent(_:for:)`, `recordAlert(_:for:)`, `shouldEvaluate(isAllDay:title:eventStart:key:workingHours:ignoreList:)`, `pruneState(referenceDate:)`. Names used identically across tasks.
- **Compile order:** pure models (Tasks 1–3) precede the service rewrite (Task 4); Task 1's `OccurrenceKey` test only goes green after Task 4 re-keys the maps — flagged inline.
- **Thoroughness:** every documented edge case has a test — sub-second drift, identifier fallback chain, per-occurrence silence and dedup, all four gates in `shouldEvaluate`, pruning both maps, daytime + wrapping window boundaries, inactive day, blank/invalid/anchored/nil title patterns, and both persistence round-trips.
