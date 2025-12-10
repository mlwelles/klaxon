# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the app
xcodebuild -project Klaxon/Klaxon.xcodeproj -scheme Klaxon -configuration Debug build

# Run all tests
xcodebuild test -project Klaxon/Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'

# Run a single test
xcodebuild test -project Klaxon/Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests/testAlertWindowVisualDisplay
```

## Architecture

Klaxon is a macOS menu bar app that monitors calendar events and displays blocking modal alerts before events start.

### Core Components

- **AppDelegate** (`Sources/App/AppDelegate.swift`): Sets up the menu bar item, requests calendar permissions, and coordinates between CalendarService and AlertWindowController.

- **CalendarService** (`Sources/Services/CalendarService.swift`): Polls EventKit every 30 seconds for upcoming events. Tracks which alerts have been sent per event using `AlertType` enum. Fires callbacks at 5 minutes, 1 minute, and event start time.

- **AlertWindowController** (`Sources/Views/AlertWindowController.swift`): Creates a borderless NSWindow at `.screenSaver` level to appear above all other windows. Displays event name, time remaining, and OK button to dismiss.

### Key Design Decisions

- Uses `LSUIElement = true` in Info.plist to run as a menu bar agent (no dock icon)
- Window level `.screenSaver` ensures alerts appear above fullscreen apps
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` makes alerts visible on all spaces
- Calendar permissions use `requestFullAccessToEvents` on macOS 14+ with fallback to `requestAccess(to:)` for older versions
