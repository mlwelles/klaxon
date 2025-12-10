# Klaxon

A macOS menu bar app that delivers unmissable calendar alerts for people who need them.

## Why Klaxon?

If you have ADHD or ADD, you're probably familiar with time blindness—that phenomenon where hours pass in what feels like minutes when you're deep in focus. Standard calendar notifications are designed to be polite and unobtrusive, which is exactly the problem. When you're in a state of hyperfocus, a gentle notification badge or a brief banner is trivially easy to miss or unconsciously dismiss.

Klaxon takes a different approach. Instead of hoping you'll notice a subtle alert, it displays a blocking modal window that appears above *everything*—including fullscreen apps. It's not rude, it's reliable.

## Features

- **Menu bar app**: Runs quietly in your menu bar without cluttering your dock
- **Three-stage alerts**: Get warnings at 5 minutes, 1 minute, and when the event starts
- **Blocking modal**: Alerts appear above all windows, including fullscreen applications
- **Quick actions**: Dismiss the alert or open the event directly in Calendar.app
- **Respects your calendar**: Works with all calendars in your macOS Calendar app

## Building

```bash
xcodebuild -project Klaxon/Klaxon.xcodeproj -scheme Klaxon -configuration Release build
```

The built app will be in `Klaxon/build/Release/Klaxon.app`.

## Running Tests

```bash
xcodebuild test -project Klaxon/Klaxon.xcodeproj -scheme Klaxon -destination 'platform=macOS'
```

## Requirements

- macOS 13.0 or later
- Calendar access permission (requested on first launch)

## How It Works

Klaxon scans your calendars every 30 seconds, looking for events starting within the next 3 hours. When an event approaches, you'll receive up to three alerts:

1. **5 minutes before**: A heads-up to start wrapping up what you're doing
2. **1 minute before**: Time to context-switch
3. **At event start**: The event is happening now

Each alert displays the event name, start time, and location (if set). You can dismiss the alert or click "Open Event" to view it in Calendar.app.

## License

MIT
