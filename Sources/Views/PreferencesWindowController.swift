import AppKit
import AVFoundation
import ServiceManagement

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var warningRows: [WarningRowView] = []
    private var warningsStackView: NSStackView!
    private var addWarningButton: NSButton!
    private var alertSoundPopup: NSPopUpButton!
    private var playSoundButton: NSButton!
    private var eventStartSoundPopup: NSPopUpButton!
    private var launchAtLoginCheckbox: NSButton!
    private var audioPlayer: AVAudioPlayer?

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
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 480),
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

        // Warnings stack view (for dynamic rows)
        warningsStackView = NSStackView()
        warningsStackView.translatesAutoresizingMaskIntoConstraints = false
        warningsStackView.orientation = .vertical
        warningsStackView.alignment = .leading
        warningsStackView.spacing = 8
        contentView.addSubview(warningsStackView)

        // Add warning button
        addWarningButton = NSButton(title: "+ Add Warning", target: self, action: #selector(addWarning))
        addWarningButton.translatesAutoresizingMaskIntoConstraints = false
        addWarningButton.bezelStyle = .rounded
        addWarningButton.controlSize = .small
        contentView.addSubview(addWarningButton)

        // Event start note
        let eventStartNote = createNoteLabel("An alert is always shown when the event starts.")
        contentView.addSubview(eventStartNote)

        // Alert Sounds section header
        let soundsHeaderLabel = createSectionHeader("Alert Sounds")
        contentView.addSubview(soundsHeaderLabel)

        // Sound selection row
        let alertSoundLabel = createLabel("Sound:")
        contentView.addSubview(alertSoundLabel)

        alertSoundPopup = createAlertSoundPopup()
        contentView.addSubview(alertSoundPopup)

        playSoundButton = NSButton(title: "▶", target: self, action: #selector(playSoundPressed))
        playSoundButton.translatesAutoresizingMaskIntoConstraints = false
        playSoundButton.bezelStyle = .rounded
        playSoundButton.controlSize = .regular
        contentView.addSubview(playSoundButton)

        // Duration row
        let eventStartSoundLabel = createLabel("Duration:")
        contentView.addSubview(eventStartSoundLabel)

        eventStartSoundPopup = createSoundDurationPopup(action: #selector(eventStartSoundChanged))
        contentView.addSubview(eventStartSoundPopup)

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

            // Warnings stack view
            warningsStackView.topAnchor.constraint(equalTo: alertsHeaderLabel.bottomAnchor, constant: 12),
            warningsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            warningsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Add warning button
            addWarningButton.topAnchor.constraint(equalTo: warningsStackView.bottomAnchor, constant: 8),
            addWarningButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Event start note
            eventStartNote.topAnchor.constraint(equalTo: addWarningButton.bottomAnchor, constant: 12),
            eventStartNote.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Alert Sounds header
            soundsHeaderLabel.topAnchor.constraint(equalTo: eventStartNote.bottomAnchor, constant: 24),
            soundsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Sound selection row
            alertSoundLabel.topAnchor.constraint(equalTo: soundsHeaderLabel.bottomAnchor, constant: 12),
            alertSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            alertSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            alertSoundPopup.centerYAnchor.constraint(equalTo: alertSoundLabel.centerYAnchor),
            alertSoundPopup.leadingAnchor.constraint(equalTo: alertSoundLabel.trailingAnchor, constant: 8),
            alertSoundPopup.widthAnchor.constraint(equalToConstant: 150),

            playSoundButton.centerYAnchor.constraint(equalTo: alertSoundLabel.centerYAnchor),
            playSoundButton.leadingAnchor.constraint(equalTo: alertSoundPopup.trailingAnchor, constant: 8),
            playSoundButton.widthAnchor.constraint(equalToConstant: 30),

            // Duration row
            eventStartSoundLabel.topAnchor.constraint(equalTo: alertSoundLabel.bottomAnchor, constant: 12),
            eventStartSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            eventStartSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            eventStartSoundPopup.centerYAnchor.constraint(equalTo: eventStartSoundLabel.centerYAnchor),
            eventStartSoundPopup.leadingAnchor.constraint(equalTo: eventStartSoundLabel.trailingAnchor, constant: 8),
            eventStartSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            // General header
            generalHeaderLabel.topAnchor.constraint(equalTo: eventStartSoundLabel.bottomAnchor, constant: 24),
            generalHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Launch at login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: generalHeaderLabel.bottomAnchor, constant: 12),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])

        window.contentView = contentView
    }

    // MARK: - UI Factory Methods

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

    private func createCheckbox(title: String, action: Selector) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: action)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        return checkbox
    }

    private func createSoundDurationPopup(action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        for option in soundDurationOptions {
            popup.addItem(withTitle: option.title)
        }
        popup.target = self
        popup.action = action
        return popup
    }

    private func createAlertSoundPopup() -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        for sound in Preferences.availableSounds {
            popup.addItem(withTitle: sound.name)
        }
        popup.target = self
        popup.action = #selector(alertSoundChanged)
        return popup
    }

    private func createNoteLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - Load/Save

    private func loadPreferences() {
        let prefs = Preferences.shared

        // Load warnings
        for warning in prefs.warnings {
            addWarningRow(warning: warning)
        }

        // Select the current alert sound
        if let soundIndex = Preferences.availableSounds.firstIndex(where: { $0.id == prefs.alertSound }) {
            alertSoundPopup.selectItem(at: soundIndex)
        }

        selectSoundDuration(prefs.eventStartSoundDuration, in: eventStartSoundPopup)
        updateSoundControlsEnabled()

        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func saveWarnings() {
        let warnings = warningRows.map { $0.warning }
        Preferences.shared.warnings = warnings
    }

    private func selectSoundDuration(_ duration: Double, in popup: NSPopUpButton) {
        if let index = soundDurationOptions.firstIndex(where: { $0.value == duration }) {
            popup.selectItem(at: index)
        } else {
            let closestIndex = soundDurationOptions.enumerated().min(by: {
                abs($0.element.value - duration) < abs($1.element.value - duration)
            })?.offset ?? 0
            popup.selectItem(at: closestIndex)
        }
    }

    private func updateSoundControlsEnabled() {
        let soundEnabled = !Preferences.shared.alertSound.isEmpty
        eventStartSoundPopup.isEnabled = soundEnabled
        playSoundButton.isEnabled = soundEnabled
        for row in warningRows {
            row.setSoundControlEnabled(soundEnabled)
        }
    }

    // MARK: - Warning Row Management

    private func addWarningRow(warning: AlertWarning) {
        let row = WarningRowView(
            warning: warning,
            soundDurationOptions: soundDurationOptions,
            onDelete: { [weak self] row in
                self?.removeWarningRow(row)
            },
            onChange: { [weak self] in
                self?.saveWarnings()
            }
        )
        row.setSoundControlEnabled(!Preferences.shared.alertSound.isEmpty)
        warningRows.append(row)
        warningsStackView.addArrangedSubview(row)
    }

    private func removeWarningRow(_ row: WarningRowView) {
        guard warningRows.count > 1 else { return } // Keep at least one warning
        if let index = warningRows.firstIndex(where: { $0 === row }) {
            warningRows.remove(at: index)
            warningsStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
            saveWarnings()
        }
    }

    @objc private func addWarning() {
        let newWarning = AlertWarning(minutesBefore: 5, soundDuration: 2.0)
        addWarningRow(warning: newWarning)
        saveWarnings()
    }

    // MARK: - Actions

    @objc private func eventStartSoundChanged() {
        let index = eventStartSoundPopup.indexOfSelectedItem
        Preferences.shared.eventStartSoundDuration = soundDurationOptions[index].value
    }

    @objc private func alertSoundChanged() {
        let index = alertSoundPopup.indexOfSelectedItem
        Preferences.shared.alertSound = Preferences.availableSounds[index].id
        updateSoundControlsEnabled()
    }

    @objc private func playSoundPressed() {
        audioPlayer?.stop()
        audioPlayer = nil

        let soundName = Preferences.shared.alertSound
        guard !soundName.isEmpty,
              let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // Silently fail if audio playback fails
        }
    }

    @objc private func launchAtLoginToggled() {
        do {
            if launchAtLoginCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
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

// MARK: - Warning Row View

private class WarningRowView: NSView {
    private(set) var warning: AlertWarning
    private let soundDurationOptions: [(title: String, value: Double)]
    private let onDelete: (WarningRowView) -> Void
    private let onChange: () -> Void

    private var minutesTextField: NSTextField!
    private var minutesStepper: NSStepper!
    private var soundPopup: NSPopUpButton!
    private var deleteButton: NSButton!

    init(warning: AlertWarning,
         soundDurationOptions: [(title: String, value: Double)],
         onDelete: @escaping (WarningRowView) -> Void,
         onChange: @escaping () -> Void) {
        self.warning = warning
        self.soundDurationOptions = soundDurationOptions
        self.onDelete = onDelete
        self.onChange = onChange
        super.init(frame: .zero)
        setupViews()
        loadValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        // Minutes text field
        minutesTextField = NSTextField()
        minutesTextField.translatesAutoresizingMaskIntoConstraints = false
        minutesTextField.alignment = .center
        minutesTextField.isEditable = false
        minutesTextField.isSelectable = false
        minutesTextField.isBordered = true
        minutesTextField.bezelStyle = .roundedBezel
        addSubview(minutesTextField)

        // Stepper
        minutesStepper = NSStepper()
        minutesStepper.translatesAutoresizingMaskIntoConstraints = false
        minutesStepper.minValue = 1
        minutesStepper.maxValue = 60
        minutesStepper.increment = 1
        minutesStepper.valueWraps = false
        minutesStepper.target = self
        minutesStepper.action = #selector(minutesChanged)
        addSubview(minutesStepper)

        // "minutes before" label
        let minutesLabel = NSTextField(labelWithString: "min before, sound:")
        minutesLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(minutesLabel)

        // Sound duration popup
        soundPopup = NSPopUpButton()
        soundPopup.translatesAutoresizingMaskIntoConstraints = false
        for option in soundDurationOptions {
            soundPopup.addItem(withTitle: option.title)
        }
        soundPopup.target = self
        soundPopup.action = #selector(soundDurationChanged)
        addSubview(soundPopup)

        // Delete button
        deleteButton = NSButton(title: "−", target: self, action: #selector(deletePressed))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.bezelStyle = .rounded
        deleteButton.controlSize = .small
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),

            minutesTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            minutesTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            minutesTextField.widthAnchor.constraint(equalToConstant: 40),

            minutesStepper.leadingAnchor.constraint(equalTo: minutesTextField.trailingAnchor, constant: 4),
            minutesStepper.centerYAnchor.constraint(equalTo: centerYAnchor),

            minutesLabel.leadingAnchor.constraint(equalTo: minutesStepper.trailingAnchor, constant: 8),
            minutesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            soundPopup.leadingAnchor.constraint(equalTo: minutesLabel.trailingAnchor, constant: 8),
            soundPopup.centerYAnchor.constraint(equalTo: centerYAnchor),
            soundPopup.widthAnchor.constraint(equalToConstant: 100),

            deleteButton.leadingAnchor.constraint(equalTo: soundPopup.trailingAnchor, constant: 8),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),

            trailingAnchor.constraint(greaterThanOrEqualTo: deleteButton.trailingAnchor),
        ])
    }

    private func loadValues() {
        minutesTextField.stringValue = "\(warning.minutesBefore)"
        minutesStepper.integerValue = warning.minutesBefore

        if let index = soundDurationOptions.firstIndex(where: { $0.value == warning.soundDuration }) {
            soundPopup.selectItem(at: index)
        }
    }

    func setSoundControlEnabled(_ enabled: Bool) {
        soundPopup.isEnabled = enabled
    }

    @objc private func minutesChanged() {
        let minutes = minutesStepper.integerValue
        minutesTextField.stringValue = "\(minutes)"
        warning.minutesBefore = minutes
        onChange()
    }

    @objc private func soundDurationChanged() {
        let index = soundPopup.indexOfSelectedItem
        warning.soundDuration = soundDurationOptions[index].value
        onChange()
    }

    @objc private func deletePressed() {
        onDelete(self)
    }
}
