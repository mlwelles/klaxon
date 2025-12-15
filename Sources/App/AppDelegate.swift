import AppKit
import EventKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var calendarService: CalendarService?
    private var alertWindowController: AlertWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var aboutWindowController: AboutWindowController?
    private var welcomeWindowController: WelcomeWindowController?
    private var launchedAtLogin = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Detect if launched at login by checking system uptime
        // If system booted recently (within 60 seconds), assume login launch
        let uptime = ProcessInfo.processInfo.systemUptime
        launchedAtLogin = uptime < 60

        setupMenuBarItem()

        // Show welcome modal on first launch before requesting calendar access
        if !Preferences.shared.hasLaunchedBefore {
            showWelcomeAndRequestAccess()
        } else {
            requestCalendarAccess()
            // Open preferences if manually launched (not at login)
            if !launchedAtLogin {
                DispatchQueue.main.async { [weak self] in
                    self?.openPreferences()
                }
            }
        }
    }

    private func showWelcomeAndRequestAccess() {
        welcomeWindowController = WelcomeWindowController { [weak self] in
            Preferences.shared.hasLaunchedBefore = true
            self?.requestCalendarAccess()
            // Open preferences after first launch
            DispatchQueue.main.async {
                self?.openPreferences()
            }
        }
        welcomeWindowController?.showWindow(nil)
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = "Klaxon"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Klaxon", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func requestCalendarAccess() {
        let eventStore = EKEventStore()

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleCalendarAccessResult(granted: granted, error: error, eventStore: eventStore)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleCalendarAccessResult(granted: granted, error: error, eventStore: eventStore)
                }
            }
        }
    }

    private func handleCalendarAccessResult(granted: Bool, error: Error?, eventStore: EKEventStore) {
        if granted {
            startCalendarMonitoring(eventStore: eventStore)
        } else {
            showPermissionError()
        }
    }

    private func startCalendarMonitoring(eventStore: EKEventStore) {
        calendarService = CalendarService(eventStore: eventStore)
        calendarService?.onEventAlert = { [weak self] event, alertType in
            self?.showEventAlert(event: event, alertType: alertType)
        }
        calendarService?.startMonitoring()
    }

    private func showPermissionError() {
        let alert = NSAlert()
        alert.messageText = "Calendar Access Required"
        alert.informativeText = "Klaxon needs access to your calendars to notify you about upcoming events. Please grant calendar access in System Settings > Privacy & Security > Calendars."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestCalendarAccess()
        } else {
            NSApp.terminate(nil)
        }
    }

    private func showEventAlert(event: EKEvent, alertType: AlertType) {
        DispatchQueue.main.async { [weak self] in
            self?.alertWindowController?.close()
            self?.alertWindowController = AlertWindowController(event: event, alertType: alertType)
            self?.alertWindowController?.showWindow(nil)
        }
    }

    @objc private func openAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow(nil)
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
