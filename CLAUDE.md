# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the app
xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration Debug build

# Run all tests
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'

# Run a single test
xcodebuild test -project Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS' -only-testing:KlaxonTests/AlertWindowTests/testAlertWindowVisualDisplay
```

## CI/CD

### Continuous Integration

Tests run automatically on:
- Push to `main` branch
- Pull requests targeting `main`

Workflow: `.github/workflows/ci.yml`

### Releasing

Releases are automated via GitHub Actions when you push a version tag:

```bash
# Create and push a release tag
git tag v1.0.0
git push origin v1.0.0
```

Workflow: `.github/workflows/release.yml`

The release workflow will:
1. Build the app in Release configuration
2. Code sign with Developer ID certificate
3. Submit to Apple for notarization
4. Staple the notarization ticket
5. Create DMG and ZIP artifacts
6. Publish a GitHub Release

#### Required Secrets

Configure these in GitHub → Settings → Secrets and variables → Actions:

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded Developer ID Application certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the .p12 file |
| `APPLE_TEAM_ID` | 10-character Apple Team ID |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com |

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
