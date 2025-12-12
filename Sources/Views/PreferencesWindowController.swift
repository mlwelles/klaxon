import AppKit
import AVFoundation
import ServiceManagement

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var firstAlertCheckbox: NSButton!
    private var firstAlertStepper: NSStepper!
    private var firstAlertTextField: NSTextField!
    private var firstAlertSoundPopup: NSPopUpButton!
    private var firstAlertPlayButton: NSButton!
    private var secondAlertCheckbox: NSButton!
    private var secondAlertStepper: NSStepper!
    private var secondAlertTextField: NSTextField!
    private var secondAlertSoundPopup: NSPopUpButton!
    private var secondAlertPlayButton: NSButton!
    private var eventStartSoundPopup: NSPopUpButton!
    private var eventStartPlayButton: NSButton!
    private var launchAtLoginCheckbox: NSButton!

    private var previewPlayer: AVAudioPlayer?
    private var previewStopTimer: Timer?

    private let soundDurationOptions: [(title: String, value: Double)] = [
        ("No sound", 0),
        ("1 second", 1.0),
        ("2 seconds", 2.0),
        ("3 seconds", 3.0),
        ("4 seconds", 4.0),
        ("5 seconds", 5.0),
        ("6 seconds", 6.0),
        ("7 seconds", 7.0),
        ("8 seconds", 8.0),
        ("9 seconds", 9.0),
        ("10 seconds", 10.0)
    ]

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 420),
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

        // Alerts section header
        let alertsHeaderLabel = createSectionHeader("Alerts")
        contentView.addSubview(alertsHeaderLabel)

        // First alert row
        firstAlertCheckbox = createCheckbox(title: "First warning", action: #selector(firstAlertToggled))
        contentView.addSubview(firstAlertCheckbox)

        firstAlertTextField = createMinutesTextField()
        contentView.addSubview(firstAlertTextField)

        firstAlertStepper = createMinutesStepper(action: #selector(firstAlertMinutesChanged))
        contentView.addSubview(firstAlertStepper)

        let firstMinutesLabel = createLabel("minutes before")
        contentView.addSubview(firstMinutesLabel)

        // Second alert row
        secondAlertCheckbox = createCheckbox(title: "Second warning", action: #selector(secondAlertToggled))
        contentView.addSubview(secondAlertCheckbox)

        secondAlertTextField = createMinutesTextField()
        contentView.addSubview(secondAlertTextField)

        secondAlertStepper = createMinutesStepper(action: #selector(secondAlertMinutesChanged))
        contentView.addSubview(secondAlertStepper)

        let secondMinutesLabel = createLabel("minutes before")
        contentView.addSubview(secondMinutesLabel)

        // Event start note
        let eventStartNote = createNoteLabel("An alert is always shown when the event starts.")
        contentView.addSubview(eventStartNote)

        // Alert Sounds section header
        let soundsHeaderLabel = createSectionHeader("Alert Sounds")
        contentView.addSubview(soundsHeaderLabel)

        // First alert sound row
        let firstAlertSoundLabel = createLabel("First warning:")
        contentView.addSubview(firstAlertSoundLabel)

        firstAlertSoundPopup = createSoundPopup(action: #selector(firstAlertSoundChanged))
        contentView.addSubview(firstAlertSoundPopup)

        firstAlertPlayButton = createPlayButton(action: #selector(playFirstAlertSound))
        contentView.addSubview(firstAlertPlayButton)

        // Second alert sound row
        let secondAlertSoundLabel = createLabel("Second warning:")
        contentView.addSubview(secondAlertSoundLabel)

        secondAlertSoundPopup = createSoundPopup(action: #selector(secondAlertSoundChanged))
        contentView.addSubview(secondAlertSoundPopup)

        secondAlertPlayButton = createPlayButton(action: #selector(playSecondAlertSound))
        contentView.addSubview(secondAlertPlayButton)

        // Event start sound row
        let eventStartSoundLabel = createLabel("Event start:")
        contentView.addSubview(eventStartSoundLabel)

        eventStartSoundPopup = createSoundPopup(action: #selector(eventStartSoundChanged))
        contentView.addSubview(eventStartSoundPopup)

        eventStartPlayButton = createPlayButton(action: #selector(playEventStartSound))
        contentView.addSubview(eventStartPlayButton)

        // General section header
        let generalHeaderLabel = createSectionHeader("General")
        contentView.addSubview(generalHeaderLabel)

        // Launch at login checkbox
        launchAtLoginCheckbox = createCheckbox(title: "Start Klaxon at login", action: #selector(launchAtLoginToggled))
        contentView.addSubview(launchAtLoginCheckbox)

        NSLayoutConstraint.activate([
            // Alerts header
            alertsHeaderLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            alertsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // First alert row
            firstAlertCheckbox.topAnchor.constraint(equalTo: alertsHeaderLabel.bottomAnchor, constant: 12),
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
            secondAlertCheckbox.topAnchor.constraint(equalTo: firstAlertCheckbox.bottomAnchor, constant: 12),
            secondAlertCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondAlertCheckbox.widthAnchor.constraint(equalToConstant: 100),

            secondAlertTextField.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondAlertTextField.leadingAnchor.constraint(equalTo: secondAlertCheckbox.trailingAnchor, constant: 10),
            secondAlertTextField.widthAnchor.constraint(equalToConstant: 40),

            secondAlertStepper.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondAlertStepper.leadingAnchor.constraint(equalTo: secondAlertTextField.trailingAnchor, constant: 4),

            secondMinutesLabel.centerYAnchor.constraint(equalTo: secondAlertCheckbox.centerYAnchor),
            secondMinutesLabel.leadingAnchor.constraint(equalTo: secondAlertStepper.trailingAnchor, constant: 8),

            // Event start note
            eventStartNote.topAnchor.constraint(equalTo: secondAlertCheckbox.bottomAnchor, constant: 12),
            eventStartNote.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Alert Sounds header
            soundsHeaderLabel.topAnchor.constraint(equalTo: eventStartNote.bottomAnchor, constant: 24),
            soundsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // First alert sound row
            firstAlertSoundLabel.topAnchor.constraint(equalTo: soundsHeaderLabel.bottomAnchor, constant: 12),
            firstAlertSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            firstAlertSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            firstAlertSoundPopup.centerYAnchor.constraint(equalTo: firstAlertSoundLabel.centerYAnchor),
            firstAlertSoundPopup.leadingAnchor.constraint(equalTo: firstAlertSoundLabel.trailingAnchor, constant: 8),
            firstAlertSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            firstAlertPlayButton.centerYAnchor.constraint(equalTo: firstAlertSoundLabel.centerYAnchor),
            firstAlertPlayButton.leadingAnchor.constraint(equalTo: firstAlertSoundPopup.trailingAnchor, constant: 4),
            firstAlertPlayButton.widthAnchor.constraint(equalToConstant: 60),

            // Second alert sound row
            secondAlertSoundLabel.topAnchor.constraint(equalTo: firstAlertSoundLabel.bottomAnchor, constant: 12),
            secondAlertSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondAlertSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            secondAlertSoundPopup.centerYAnchor.constraint(equalTo: secondAlertSoundLabel.centerYAnchor),
            secondAlertSoundPopup.leadingAnchor.constraint(equalTo: secondAlertSoundLabel.trailingAnchor, constant: 8),
            secondAlertSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            secondAlertPlayButton.centerYAnchor.constraint(equalTo: secondAlertSoundLabel.centerYAnchor),
            secondAlertPlayButton.leadingAnchor.constraint(equalTo: secondAlertSoundPopup.trailingAnchor, constant: 4),
            secondAlertPlayButton.widthAnchor.constraint(equalToConstant: 60),

            // Event start sound row
            eventStartSoundLabel.topAnchor.constraint(equalTo: secondAlertSoundLabel.bottomAnchor, constant: 12),
            eventStartSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            eventStartSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            eventStartSoundPopup.centerYAnchor.constraint(equalTo: eventStartSoundLabel.centerYAnchor),
            eventStartSoundPopup.leadingAnchor.constraint(equalTo: eventStartSoundLabel.trailingAnchor, constant: 8),
            eventStartSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            eventStartPlayButton.centerYAnchor.constraint(equalTo: eventStartSoundLabel.centerYAnchor),
            eventStartPlayButton.leadingAnchor.constraint(equalTo: eventStartSoundPopup.trailingAnchor, constant: 4),
            eventStartPlayButton.widthAnchor.constraint(equalToConstant: 60),

            // General header
            generalHeaderLabel.topAnchor.constraint(equalTo: eventStartSoundLabel.bottomAnchor, constant: 24),
            generalHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Launch at login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: generalHeaderLabel.bottomAnchor, constant: 12),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])

        window.contentView = contentView
    }

    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createMinutesTextField() -> NSTextField {
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.alignment = .center
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        return textField
    }

    private func createMinutesStepper(action: Selector) -> NSStepper {
        let stepper = NSStepper()
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.minValue = 1
        stepper.maxValue = 60
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = action
        return stepper
    }

    private func createCheckbox(title: String, action: Selector) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: action)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }

    private func createSoundPopup(action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        for option in soundDurationOptions {
            popup.addItem(withTitle: option.title)
        }
        popup.target = self
        popup.action = action
        return popup
    }

    private func createPlayButton(action: Selector) -> NSButton {
        let button = NSButton(title: "Preview", target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return button
    }

    private func createNoteLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func selectSoundDuration(_ duration: Double, in popup: NSPopUpButton) {
        if let index = soundDurationOptions.firstIndex(where: { $0.value == duration }) {
            popup.selectItem(at: index)
        } else {
            // If exact match not found, select closest option
            let closestIndex = soundDurationOptions.enumerated().min(by: {
                abs($0.element.value - duration) < abs($1.element.value - duration)
            })?.offset ?? 0
            popup.selectItem(at: closestIndex)
        }
    }

    private func loadPreferences() {
        let prefs = Preferences.shared

        firstAlertCheckbox.state = prefs.firstAlertEnabled ? .on : .off
        firstAlertStepper.integerValue = prefs.firstAlertMinutes
        firstAlertTextField.stringValue = "\(prefs.firstAlertMinutes)"
        selectSoundDuration(prefs.firstAlertSoundDuration, in: firstAlertSoundPopup)
        updateFirstAlertControlsEnabled()

        secondAlertCheckbox.state = prefs.secondAlertEnabled ? .on : .off
        secondAlertStepper.integerValue = prefs.secondAlertMinutes
        secondAlertTextField.stringValue = "\(prefs.secondAlertMinutes)"
        selectSoundDuration(prefs.secondAlertSoundDuration, in: secondAlertSoundPopup)
        updateSecondAlertControlsEnabled()

        selectSoundDuration(prefs.eventStartSoundDuration, in: eventStartSoundPopup)

        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func updateFirstAlertControlsEnabled() {
        let enabled = firstAlertCheckbox.state == .on
        firstAlertStepper.isEnabled = enabled
        firstAlertTextField.isEnabled = enabled
        firstAlertTextField.textColor = enabled ? .labelColor : .disabledControlTextColor
        firstAlertSoundPopup.isEnabled = enabled
        firstAlertPlayButton.isEnabled = enabled
    }

    private func updateSecondAlertControlsEnabled() {
        let enabled = secondAlertCheckbox.state == .on
        secondAlertStepper.isEnabled = enabled
        secondAlertTextField.isEnabled = enabled
        secondAlertTextField.textColor = enabled ? .labelColor : .disabledControlTextColor
        secondAlertSoundPopup.isEnabled = enabled
        secondAlertPlayButton.isEnabled = enabled
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

    @objc private func firstAlertSoundChanged() {
        let index = firstAlertSoundPopup.indexOfSelectedItem
        Preferences.shared.firstAlertSoundDuration = soundDurationOptions[index].value
    }

    @objc private func secondAlertSoundChanged() {
        let index = secondAlertSoundPopup.indexOfSelectedItem
        Preferences.shared.secondAlertSoundDuration = soundDurationOptions[index].value
    }

    @objc private func eventStartSoundChanged() {
        let index = eventStartSoundPopup.indexOfSelectedItem
        Preferences.shared.eventStartSoundDuration = soundDurationOptions[index].value
    }

    @objc private func playFirstAlertSound() {
        let index = firstAlertSoundPopup.indexOfSelectedItem
        let duration = soundDurationOptions[index].value
        playPreviewSound(duration: duration)
    }

    @objc private func playSecondAlertSound() {
        let index = secondAlertSoundPopup.indexOfSelectedItem
        let duration = soundDurationOptions[index].value
        playPreviewSound(duration: duration)
    }

    @objc private func playEventStartSound() {
        let index = eventStartSoundPopup.indexOfSelectedItem
        let duration = soundDurationOptions[index].value
        playPreviewSound(duration: duration)
    }

    private func playPreviewSound(duration: TimeInterval) {
        // Stop any existing preview
        stopPreviewSound()

        guard duration > 0 else { return }

        guard let soundURL = Bundle.main.url(forResource: "fire-alarm-bell", withExtension: "mp3") else {
            return
        }

        do {
            previewPlayer = try AVAudioPlayer(contentsOf: soundURL)
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()

            previewStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stopPreviewSound()
            }
        } catch {
            // Silently fail if audio playback fails
        }
    }

    private func stopPreviewSound() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewStopTimer?.invalidate()
        previewStopTimer = nil
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
