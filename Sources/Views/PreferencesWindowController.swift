import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var firstAlertCheckbox: NSButton!
    private var firstAlertStepper: NSStepper!
    private var firstAlertTextField: NSTextField!
    private var secondAlertCheckbox: NSButton!
    private var secondAlertStepper: NSStepper!
    private var secondAlertTextField: NSTextField!
    private var launchAtLoginCheckbox: NSButton!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Klaxon Preferences"
        window.center()

        super.init(window: window)
        window.delegate = self

        setupContent()
        loadPreferences()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))

        // Section header
        let headerLabel = NSTextField(labelWithString: "Alert Timing")
        headerLabel.font = .boldSystemFont(ofSize: 13)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerLabel)

        // First alert row
        firstAlertCheckbox = NSButton(checkboxWithTitle: "First alert", target: self, action: #selector(firstAlertToggled))
        firstAlertCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(firstAlertCheckbox)

        firstAlertTextField = NSTextField()
        firstAlertTextField.translatesAutoresizingMaskIntoConstraints = false
        firstAlertTextField.alignment = .center
        firstAlertTextField.isEditable = false
        firstAlertTextField.isSelectable = false
        firstAlertTextField.isBordered = true
        firstAlertTextField.bezelStyle = .roundedBezel
        contentView.addSubview(firstAlertTextField)

        firstAlertStepper = NSStepper()
        firstAlertStepper.translatesAutoresizingMaskIntoConstraints = false
        firstAlertStepper.minValue = 1
        firstAlertStepper.maxValue = 60
        firstAlertStepper.increment = 1
        firstAlertStepper.valueWraps = false
        firstAlertStepper.target = self
        firstAlertStepper.action = #selector(firstAlertMinutesChanged)
        contentView.addSubview(firstAlertStepper)

        let firstMinutesLabel = NSTextField(labelWithString: "minutes before event")
        firstMinutesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(firstMinutesLabel)

        // Second alert row
        secondAlertCheckbox = NSButton(checkboxWithTitle: "Second alert", target: self, action: #selector(secondAlertToggled))
        secondAlertCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secondAlertCheckbox)

        secondAlertTextField = NSTextField()
        secondAlertTextField.translatesAutoresizingMaskIntoConstraints = false
        secondAlertTextField.alignment = .center
        secondAlertTextField.isEditable = false
        secondAlertTextField.isSelectable = false
        secondAlertTextField.isBordered = true
        secondAlertTextField.bezelStyle = .roundedBezel
        contentView.addSubview(secondAlertTextField)

        secondAlertStepper = NSStepper()
        secondAlertStepper.translatesAutoresizingMaskIntoConstraints = false
        secondAlertStepper.minValue = 1
        secondAlertStepper.maxValue = 60
        secondAlertStepper.increment = 1
        secondAlertStepper.valueWraps = false
        secondAlertStepper.target = self
        secondAlertStepper.action = #selector(secondAlertMinutesChanged)
        contentView.addSubview(secondAlertStepper)

        let secondMinutesLabel = NSTextField(labelWithString: "minutes before event")
        secondMinutesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secondMinutesLabel)

        // Note about event start alert
        let noteLabel = NSTextField(labelWithString: "An alert is always shown when the event starts.")
        noteLabel.font = .systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noteLabel)

        // General section header
        let generalHeaderLabel = NSTextField(labelWithString: "General")
        generalHeaderLabel.font = .boldSystemFont(ofSize: 13)
        generalHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(generalHeaderLabel)

        // Launch at login checkbox
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Start Klaxon at login", target: self, action: #selector(launchAtLoginToggled))
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(launchAtLoginCheckbox)

        NSLayoutConstraint.activate([
            // Header
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // First alert row
            firstAlertCheckbox.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            firstAlertCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            firstAlertCheckbox.widthAnchor.constraint(equalToConstant: 100),

            firstAlertTextField.centerYAnchor.constraint(equalTo: firstAlertCheckbox.centerYAnchor),
            firstAlertTextField.leadingAnchor.constraint(equalTo: firstAlertCheckbox.trailingAnchor, constant: 10),
            firstAlertTextField.widthAnchor.constraint(equalToConstant: 40),

            firstAlertStepper.centerYAnchor.constraint(equalTo: firstAlertCheckbox.centerYAnchor),
            firstAlertStepper.leadingAnchor.constraint(equalTo: firstAlertTextField.trailingAnchor, constant: 4),

            firstMinutesLabel.centerYAnchor.constraint(equalTo: firstAlertCheckbox.centerYAnchor),
            firstMinutesLabel.leadingAnchor.constraint(equalTo: firstAlertStepper.trailingAnchor, constant: 8),

            // Second alert row
            secondAlertCheckbox.topAnchor.constraint(equalTo: firstAlertCheckbox.bottomAnchor, constant: 16),
            secondAlertCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondAlertCheckbox.widthAnchor.constraint(equalToConstant: 100),

            secondAlertTextField.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondAlertTextField.leadingAnchor.constraint(equalTo: secondAlertCheckbox.trailingAnchor, constant: 10),
            secondAlertTextField.widthAnchor.constraint(equalToConstant: 40),

            secondAlertStepper.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondAlertStepper.leadingAnchor.constraint(equalTo: secondAlertTextField.trailingAnchor, constant: 4),

            secondMinutesLabel.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondMinutesLabel.leadingAnchor.constraint(equalTo: secondAlertStepper.trailingAnchor, constant: 8),

            // Note
            noteLabel.topAnchor.constraint(equalTo: secondAlertCheckbox.bottomAnchor, constant: 16),
            noteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // General header
            generalHeaderLabel.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 24),
            generalHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Launch at login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: generalHeaderLabel.bottomAnchor, constant: 12),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])

        window.contentView = contentView
    }

    private func loadPreferences() {
        let prefs = Preferences.shared

        firstAlertCheckbox.state = prefs.firstAlertEnabled ? .on : .off
        firstAlertStepper.integerValue = prefs.firstAlertMinutes
        firstAlertTextField.stringValue = "\(prefs.firstAlertMinutes)"
        updateFirstAlertControlsEnabled()

        secondAlertCheckbox.state = prefs.secondAlertEnabled ? .on : .off
        secondAlertStepper.integerValue = prefs.secondAlertMinutes
        secondAlertTextField.stringValue = "\(prefs.secondAlertMinutes)"
        updateSecondAlertControlsEnabled()

        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func updateFirstAlertControlsEnabled() {
        let enabled = firstAlertCheckbox.state == .on
        firstAlertStepper.isEnabled = enabled
        firstAlertTextField.isEnabled = enabled
        firstAlertTextField.textColor = enabled ? .labelColor : .disabledControlTextColor
    }

    private func updateSecondAlertControlsEnabled() {
        let enabled = secondAlertCheckbox.state == .on
        secondAlertStepper.isEnabled = enabled
        secondAlertTextField.isEnabled = enabled
        secondAlertTextField.textColor = enabled ? .labelColor : .disabledControlTextColor
    }

    @objc private func firstAlertToggled() {
        Preferences.shared.firstAlertEnabled = firstAlertCheckbox.state == .on
        updateFirstAlertControlsEnabled()
    }

    @objc private func firstAlertMinutesChanged() {
        let minutes = firstAlertStepper.integerValue
        firstAlertTextField.stringValue = "\(minutes)"
        Preferences.shared.firstAlertMinutes = minutes
    }

    @objc private func secondAlertToggled() {
        Preferences.shared.secondAlertEnabled = secondAlertCheckbox.state == .on
        updateSecondAlertControlsEnabled()
    }

    @objc private func secondAlertMinutesChanged() {
        let minutes = secondAlertStepper.integerValue
        secondAlertTextField.stringValue = "\(minutes)"
        Preferences.shared.secondAlertMinutes = minutes
    }

    @objc private func launchAtLoginToggled() {
        do {
            if launchAtLoginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert checkbox state on failure
            launchAtLoginCheckbox.state = launchAtLoginCheckbox.state == .on ? .off : .on
            let alert = NSAlert()
            alert.messageText = "Failed to update login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
