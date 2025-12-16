import AppKit
import AVFoundation
import ServiceManagement

final class PreferencesWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var warnings: [AlertWarning] = []
    private var warningsTableView: NSTableView!
    private var warningsScrollView: NSScrollView!
    private var addWarningButton: NSButton!
    private var alertSoundPopup: NSPopUpButton!
    private var eventStartSoundPopup: NSPopUpButton!
    private var launchAtLoginCheckbox: NSButton!
    private var showWindowOnLaunchCheckbox: NSButton!
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?

    private let soundDurationOptions: [(title: String, value: Double)] = [
        ("No sound", 0),
        ("1 second", 1.0),
        ("2 seconds", 2.0),
        ("3 seconds", 3.0),
        ("4 seconds", 4.0),
        ("5 seconds", 5.0)
    ]

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
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

        // Event section header
        let eventHeaderLabel = createSectionHeader("Event Alert")
        contentView.addSubview(eventHeaderLabel)

        // Event section description
        let eventDescription = createNoteLabel("Alert shown when an event starts.")
        contentView.addSubview(eventDescription)

        // Sound selection row
        let alertSoundLabel = createLabel("Play sound:")
        contentView.addSubview(alertSoundLabel)

        alertSoundPopup = createAlertSoundPopup()
        contentView.addSubview(alertSoundPopup)


        // Duration row
        let eventStartSoundLabel = createLabel("Duration:")
        contentView.addSubview(eventStartSoundLabel)

        eventStartSoundPopup = createSoundDurationPopup(action: #selector(eventStartSoundChanged))
        contentView.addSubview(eventStartSoundPopup)

        // Warnings section header
        let warningsHeaderLabel = createSectionHeader("Warning Alerts")
        contentView.addSubview(warningsHeaderLabel)

        // Warnings section description
        let warningsDescription = createNoteLabel("Optional alerts shown before event start.")
        contentView.addSubview(warningsDescription)

        // Warnings table view
        warningsTableView = NSTableView()
        warningsTableView.translatesAutoresizingMaskIntoConstraints = false
        warningsTableView.dataSource = self
        warningsTableView.delegate = self
        warningsTableView.headerView = NSTableHeaderView()
        warningsTableView.rowHeight = 28
        warningsTableView.intercellSpacing = NSSize(width: 4, height: 4)
        warningsTableView.gridStyleMask = []
        warningsTableView.backgroundColor = .clear
        warningsTableView.usesAlternatingRowBackgroundColors = false

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "When"
        timeColumn.width = 140
        warningsTableView.addTableColumn(timeColumn)

        let soundColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sound"))
        soundColumn.title = "Play Sound"
        soundColumn.width = 150
        warningsTableView.addTableColumn(soundColumn)

        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 90
        warningsTableView.addTableColumn(durationColumn)

        let removeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("remove"))
        removeColumn.title = ""
        removeColumn.width = 24
        warningsTableView.addTableColumn(removeColumn)

        warningsScrollView = NSScrollView()
        warningsScrollView.translatesAutoresizingMaskIntoConstraints = false
        warningsScrollView.documentView = warningsTableView
        warningsScrollView.hasVerticalScroller = true
        warningsScrollView.hasHorizontalScroller = false
        warningsScrollView.borderType = .bezelBorder
        warningsScrollView.autohidesScrollers = true
        contentView.addSubview(warningsScrollView)

        // Add warning button
        addWarningButton = NSButton(title: "+ Add", target: self, action: #selector(addWarning))
        addWarningButton.translatesAutoresizingMaskIntoConstraints = false
        addWarningButton.bezelStyle = .rounded
        addWarningButton.controlSize = .small
        contentView.addSubview(addWarningButton)

        // General section header
        let generalHeaderLabel = createSectionHeader("General")
        contentView.addSubview(generalHeaderLabel)

        // Launch at login checkbox
        launchAtLoginCheckbox = createCheckbox(title: "Start Klaxon at login", action: #selector(launchAtLoginToggled))
        contentView.addSubview(launchAtLoginCheckbox)

        // Show window on launch checkbox
        showWindowOnLaunchCheckbox = createCheckbox(title: "Show welcome on start", action: #selector(showWindowOnLaunchToggled))
        contentView.addSubview(showWindowOnLaunchCheckbox)

        NSLayoutConstraint.activate([
            // Event header
            eventHeaderLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            eventHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Event description
            eventDescription.topAnchor.constraint(equalTo: eventHeaderLabel.bottomAnchor, constant: 4),
            eventDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Sound selection row
            alertSoundLabel.topAnchor.constraint(equalTo: eventDescription.bottomAnchor, constant: 12),
            alertSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            alertSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            alertSoundPopup.centerYAnchor.constraint(equalTo: alertSoundLabel.centerYAnchor),
            alertSoundPopup.leadingAnchor.constraint(equalTo: alertSoundLabel.trailingAnchor, constant: 8),
            alertSoundPopup.widthAnchor.constraint(equalToConstant: 150),

            // Duration row
            eventStartSoundLabel.topAnchor.constraint(equalTo: alertSoundLabel.bottomAnchor, constant: 12),
            eventStartSoundLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            eventStartSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            eventStartSoundPopup.centerYAnchor.constraint(equalTo: eventStartSoundLabel.centerYAnchor),
            eventStartSoundPopup.leadingAnchor.constraint(equalTo: eventStartSoundLabel.trailingAnchor, constant: 8),
            eventStartSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            // Warnings header
            warningsHeaderLabel.topAnchor.constraint(equalTo: eventStartSoundLabel.bottomAnchor, constant: 24),
            warningsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Warnings description
            warningsDescription.topAnchor.constraint(equalTo: warningsHeaderLabel.bottomAnchor, constant: 4),
            warningsDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Warnings table view
            warningsScrollView.topAnchor.constraint(equalTo: warningsDescription.bottomAnchor, constant: 12),
            warningsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            warningsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            warningsScrollView.heightAnchor.constraint(equalToConstant: 100),

            // Add warning button
            addWarningButton.topAnchor.constraint(equalTo: warningsScrollView.bottomAnchor, constant: 8),
            addWarningButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // General header
            generalHeaderLabel.topAnchor.constraint(equalTo: addWarningButton.bottomAnchor, constant: 24),
            generalHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Launch at login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: generalHeaderLabel.bottomAnchor, constant: 12),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Show window on launch
            showWindowOnLaunchCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 8),
            showWindowOnLaunchCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])

        // OK button at bottom
        let okButton = NSButton(title: "OK", target: self, action: #selector(okPressed))
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)

        NSLayoutConstraint.activate([
            okButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            okButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            okButton.widthAnchor.constraint(equalToConstant: 80),
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

        // Load warnings sorted by duration (longest first)
        warnings = prefs.warnings.sorted(by: { $0.minutesBefore > $1.minutesBefore })
        warningsTableView.reloadData()

        // Select the current alert sound
        if let soundIndex = Preferences.availableSounds.firstIndex(where: { $0.id == prefs.alertSound }) {
            alertSoundPopup.selectItem(at: soundIndex)
        }

        selectSoundDuration(prefs.eventStartSoundDuration, in: eventStartSoundPopup)
        updateSoundControlsEnabled()

        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        showWindowOnLaunchCheckbox.state = Preferences.shared.showWindowOnLaunch ? .on : .off
    }

    private func saveWarnings() {
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
    }

    /// Get the maximum duration option index for a sound (first option >= actual duration)
    private func maxDurationOptionIndex(for soundName: String) -> Int {
        guard !soundName.isEmpty else { return soundDurationOptions.count - 1 }
        let actualDuration = Preferences.soundDuration(for: soundName)
        // Find the first option >= actual duration (skip "No sound" at index 0)
        for (index, option) in soundDurationOptions.enumerated() where index > 0 {
            if option.value >= actualDuration {
                return index
            }
        }
        return soundDurationOptions.count - 1  // Default to max if sound is longer than all options
    }

    /// Cap a duration to the max allowed for a sound, returns the capped value
    private func cappedDuration(_ duration: Double, for soundName: String) -> Double {
        guard !soundName.isEmpty, duration > 0 else { return duration }
        let maxIndex = maxDurationOptionIndex(for: soundName)
        let maxValue = soundDurationOptions[maxIndex].value
        return min(duration, maxValue)
    }

    // MARK: - Warning Management

    @objc private func addWarning() {
        let prefs = Preferences.shared
        let newWarning = AlertWarning(
            minutesBefore: 5,
            sound: prefs.alertSound,
            soundDuration: prefs.eventStartSoundDuration
        )
        warnings.append(newWarning)
        warningsTableView.reloadData()
        saveWarnings()
    }

    @objc private func removeWarning(_ sender: NSButton) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        warnings.remove(at: row)
        warningsTableView.reloadData()
        saveWarnings()
    }

    @objc private func warningMinutesChanged(_ sender: NSStepper) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        warnings[row].minutesBefore = sender.integerValue
        // Update the text field in the same row (find the editable-looking text field)
        if let cellView = warningsTableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSView {
            let textFields = cellView.subviews.compactMap { $0 as? NSTextField }
            // The minutes field is the one with a border/bezel (not a label)
            if let minutesField = textFields.first(where: { $0.isBordered }) {
                minutesField.stringValue = "\(sender.integerValue)"
            }
        }
        saveWarnings()
    }

    @objc private func warningSoundChanged(_ sender: NSPopUpButton) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        let index = sender.indexOfSelectedItem
        let soundName = Preferences.availableSounds[index].id
        warnings[row].sound = soundName

        // Cap duration if it exceeds the max for this sound
        let currentDuration = warnings[row].soundDuration
        let cappedValue = cappedDuration(currentDuration, for: soundName)
        if cappedValue != currentDuration {
            warnings[row].soundDuration = cappedValue
        }

        updateWarningDurationPopup(at: row)
        saveWarnings()
        playSound(warnings[row].sound, forDuration: warnings[row].soundDuration)
    }

    @objc private func warningDurationChanged(_ sender: NSPopUpButton) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        let index = sender.indexOfSelectedItem
        warnings[row].soundDuration = soundDurationOptions[index].value
        saveWarnings()
        playSound(warnings[row].sound, forDuration: warnings[row].soundDuration)
    }

    private func updateWarningDurationPopup(at row: Int) {
        guard row >= 0 && row < warnings.count else { return }
        let warning = warnings[row]

        // Duration popup is in the duration column (index 2)
        if let cellView = warningsTableView.view(atColumn: 2, row: row, makeIfNecessary: false) {
            let popups = cellView.subviews.compactMap { $0 as? NSPopUpButton }
            if let durationPopup = popups.first {
                durationPopup.isEnabled = !warning.sound.isEmpty

                // Update selection to match current duration
                if let durationIndex = soundDurationOptions.firstIndex(where: { $0.value == warning.soundDuration }) {
                    durationPopup.selectItem(at: durationIndex)
                }
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return warnings.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < warnings.count, let columnId = tableColumn?.identifier.rawValue else { return nil }
        let warning = warnings[row]

        let cellView = NSView()

        switch columnId {
        case "time":
            // Minutes text field
            let minutesField = NSTextField()
            minutesField.translatesAutoresizingMaskIntoConstraints = false
            minutesField.stringValue = "\(warning.minutesBefore)"
            minutesField.alignment = .center
            minutesField.isEditable = false
            minutesField.isSelectable = false
            minutesField.isBordered = true
            minutesField.bezelStyle = .roundedBezel
            cellView.addSubview(minutesField)

            // Minutes stepper
            let stepper = NSStepper()
            stepper.translatesAutoresizingMaskIntoConstraints = false
            stepper.minValue = 1
            stepper.maxValue = 60
            stepper.integerValue = warning.minutesBefore
            stepper.target = self
            stepper.action = #selector(warningMinutesChanged(_:))
            cellView.addSubview(stepper)

            // "min before event" label
            let minLabel = NSTextField(labelWithString: "min before event")
            minLabel.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(minLabel)

            NSLayoutConstraint.activate([
                minutesField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                minutesField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                minutesField.widthAnchor.constraint(equalToConstant: 32),

                stepper.leadingAnchor.constraint(equalTo: minutesField.trailingAnchor, constant: 2),
                stepper.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

                minLabel.leadingAnchor.constraint(equalTo: stepper.trailingAnchor, constant: 4),
                minLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])

        case "sound":
            // Sound popup
            let soundPopup = NSPopUpButton()
            soundPopup.translatesAutoresizingMaskIntoConstraints = false
            soundPopup.controlSize = .small
            soundPopup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            for sound in Preferences.availableSounds {
                soundPopup.addItem(withTitle: sound.name)
            }
            if let soundIndex = Preferences.availableSounds.firstIndex(where: { $0.id == warning.sound }) {
                soundPopup.selectItem(at: soundIndex)
            }
            soundPopup.target = self
            soundPopup.action = #selector(warningSoundChanged(_:))
            cellView.addSubview(soundPopup)

            NSLayoutConstraint.activate([
                soundPopup.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                soundPopup.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                soundPopup.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
            ])

        case "duration":
            // Duration popup
            let durationPopup = NSPopUpButton()
            durationPopup.translatesAutoresizingMaskIntoConstraints = false
            durationPopup.controlSize = .small
            durationPopup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            for option in soundDurationOptions {
                durationPopup.addItem(withTitle: option.title)
            }
            if let durationIndex = soundDurationOptions.firstIndex(where: { $0.value == warning.soundDuration }) {
                durationPopup.selectItem(at: durationIndex)
            }
            durationPopup.isEnabled = !warning.sound.isEmpty
            durationPopup.target = self
            durationPopup.action = #selector(warningDurationChanged(_:))
            cellView.addSubview(durationPopup)

            NSLayoutConstraint.activate([
                durationPopup.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                durationPopup.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                durationPopup.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
            ])

        case "remove":
            let button = NSButton(title: "", target: self, action: #selector(removeWarning(_:)))
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.controlSize = .small
            if let trashImage = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove") {
                button.image = trashImage
            }
            button.imagePosition = .imageOnly
            cellView.addSubview(button)

            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                button.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 24),
            ])

        default:
            break
        }

        return cellView
    }

    // MARK: - Actions

    @objc private func eventStartSoundChanged() {
        let index = eventStartSoundPopup.indexOfSelectedItem
        Preferences.shared.eventStartSoundDuration = soundDurationOptions[index].value
        playEventAlertSound()
    }

    @objc private func alertSoundChanged() {
        let index = alertSoundPopup.indexOfSelectedItem
        let soundName = Preferences.availableSounds[index].id
        Preferences.shared.alertSound = soundName
        updateSoundControlsEnabled()

        // Cap duration if it exceeds the max for this sound
        let currentDuration = Preferences.shared.eventStartSoundDuration
        let cappedValue = cappedDuration(currentDuration, for: soundName)
        if cappedValue != currentDuration {
            Preferences.shared.eventStartSoundDuration = cappedValue
            selectSoundDuration(cappedValue, in: eventStartSoundPopup)
        }

        playEventAlertSound()
    }

    private func playEventAlertSound() {
        let duration = Preferences.shared.eventStartSoundDuration
        let soundName = Preferences.shared.alertSound
        playSound(soundName, forDuration: duration)
    }

    private func fadeOutDuration(for duration: Double) -> TimeInterval {
        if duration >= 2 { return 0.5 }
        return 0  // No fade for 1 second or less
    }

    private func playSound(_ soundName: String, forDuration duration: Double) {
        audioStopTimer?.invalidate()
        audioStopTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil

        guard duration > 0, !soundName.isEmpty,
              let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            let fadeDuration = fadeOutDuration(for: duration)
            if fadeDuration > 0 {
                // Start fade-out before duration ends, then stop after fade completes
                let fadeStartTime = duration - fadeDuration
                audioStopTimer = Timer.scheduledTimer(withTimeInterval: fadeStartTime, repeats: false) { [weak self] _ in
                    self?.audioPlayer?.setVolume(0, fadeDuration: fadeDuration)
                    // Schedule stop after fade completes
                    Timer.scheduledTimer(withTimeInterval: fadeDuration, repeats: false) { [weak self] _ in
                        self?.audioPlayer?.stop()
                        self?.audioPlayer = nil
                    }
                }
            } else {
                // No fade, just stop at duration
                audioStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.audioPlayer?.stop()
                    self?.audioPlayer = nil
                }
            }
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

    @objc private func showWindowOnLaunchToggled() {
        Preferences.shared.showWindowOnLaunch = showWindowOnLaunchCheckbox.state == .on
    }

    @objc private func okPressed() {
        window?.close()
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
