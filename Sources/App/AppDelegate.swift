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

        // On first launch, show welcome window before setting up menu bar or requesting calendar access
        if !Preferences.shared.hasLaunchedBefore {
            showWelcomeAndRequestAccess()
        } else {
            setupMenuBarItem()
            requestCalendarAccess()
            // Show welcome window if manually launched and preference is enabled
            if !launchedAtLogin && Preferences.shared.showWindowOnLaunch {
                DispatchQueue.main.async { [weak self] in
                    self?.showWelcome()
                }
            }
        }
    }

    private func showWelcomeAndRequestAccess() {
        welcomeWindowController = WelcomeWindowController(
            onDismiss: { [weak self] in
                Preferences.shared.hasLaunchedBefore = true
                Preferences.shared.showWindowOnLaunch = false
                self?.setupMenuBarItem()
                self?.requestCalendarAccess()
            }
        )
        welcomeWindowController?.showWindow(nil)
    }

    private func showWelcome() {
        welcomeWindowController = WelcomeWindowController(onDismiss: {})
        welcomeWindowController?.showWindow(nil)
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = NSLocalizedString("app.name", comment: "App name")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.about", comment: "About menu item"), action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.preferences", comment: "Preferences menu item"), action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Quit menu item"), action: #selector(quitApp), keyEquivalent: "q"))
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
        alert.messageText = NSLocalizedString("calendar.accessRequired.title", comment: "Calendar access required title")
        alert.informativeText = NSLocalizedString("calendar.accessRequired.message", comment: "Calendar access required message")
        alert.alertStyle = .critical
        alert.addButton(withTitle: NSLocalizedString("calendar.accessRequired.retry", comment: "Retry button"))
        alert.addButton(withTitle: NSLocalizedString("calendar.accessRequired.quit", comment: "Quit button"))

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
