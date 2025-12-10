# Klaxon

## Project Overview

Klaxon is a macOS menu bar application that provides timely alerts for upcoming calendar events. It's written in Swift and uses the SwiftUI and AppKit frameworks. The application leverages the EventKit framework to access and monitor the user's calendar for upcoming events. When an event is approaching, Klaxon displays an alert window to notify the user.

The application is structured into the following components:

-   **App:** The main application entry point and delegate.
-   **Services:** The `CalendarService` is responsible for monitoring the user's calendar for upcoming events.
-   **Views:** The `AlertWindowController` is responsible for displaying the alert window when a calendar event is approaching.
-   **Tests:** The project includes unit tests for the `AlertWindowController` and `CalendarService`.

## Building and Running

To build and run the project, you can use Xcode. Open the `Klaxon.xcodeproj` file and run the "Klaxon" scheme.

```bash
xcodebuild -scheme Klaxon build
```

To run the tests, you can use the "test" action in Xcode or run the following command in your terminal:

```bash
xcodebuild -scheme Klaxon -destination 'platform=macOS' test
```

## Development Conventions

The project follows the standard Swift and macOS development conventions. The code is organized into separate files for each class and related functionality. The project also includes unit tests to ensure the quality of the code.
