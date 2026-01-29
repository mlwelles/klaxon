import AppKit
import AVFoundation
import EventKit
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
    private var respectDNDCheckbox: NSButton!
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?
    private var calendarsTableView: NSTableView!
    private var calendarsScrollView: NSScrollView!
    private var eventStore: EKEventStore?
    private var availableCalendars: [EKCalendar] = []
    private var noCalendarsLabel: NSTextField!
    private let loginItemService: LoginItemServiceProtocol

    private var soundDurationOptions: [(title: String, value: Double)] {
        [
            (NSLocalizedString("preferences.duration.noSound", comment: "No sound option"), 0),
            (NSLocalizedString("preferences.duration.oneSecond", comment: "1 second"), 1.0),
            (String(format: NSLocalizedString("preferences.duration.seconds", comment: "%d seconds"), 2), 2.0),
            (String(format: NSLocalizedString("preferences.duration.seconds", comment: "%d seconds"), 3), 3.0),
            (String(format: NSLocalizedString("preferences.duration.seconds", comment: "%d seconds"), 4), 4.0),
            (String(format: NSLocalizedString("preferences.duration.seconds", comment: "%d seconds"), 5), 5.0)
        ]
    }

    init(loginItemService: LoginItemServiceProtocol = LoginItemService.shared) {
        self.loginItemService = loginItemService

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("preferences.title", comment: "Preferences window title")
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

        // Create tab view
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.setAccessibilityIdentifier("preferencesTabView")
        tabView.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.tabView", comment: "Preferences sections"))
        contentView.addSubview(tabView)

        // Create tabs
        let alertTab = NSTabViewItem(identifier: "alert")
        alertTab.label = NSLocalizedString("preferences.tab.alert", comment: "Alert tab label")
        alertTab.view = createAlertTabContent()
        tabView.addTabViewItem(alertTab)

        let calendarTab = NSTabViewItem(identifier: "calendar")
        calendarTab.label = NSLocalizedString("preferences.tab.calendar", comment: "Calendar tab label")
        calendarTab.view = createCalendarTabContent()
        tabView.addTabViewItem(calendarTab)

        let otherTab = NSTabViewItem(identifier: "other")
        otherTab.label = NSLocalizedString("preferences.tab.other", comment: "Other tab label")
        otherTab.view = createOtherTabContent()
        tabView.addTabViewItem(otherTab)

        // OK button at bottom
        let okButton = NSButton(title: NSLocalizedString("preferences.button.ok", comment: "OK button"), target: self, action: #selector(okPressed))
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.setAccessibilityIdentifier("okButton")
        okButton.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.okButton", comment: "OK, close Preferences window"))
        contentView.addSubview(okButton)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: okButton.topAnchor, constant: -12),

            okButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            okButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            okButton.widthAnchor.constraint(equalToConstant: 80),
        ])

        window.contentView = contentView
    }

    // MARK: - Tab Content Creation

    private func createAlertTabContent() -> NSView {
        let tabContent = NSView()

        // Event section header
        let eventHeaderLabel = createSectionHeader(NSLocalizedString("preferences.eventAlert.header", comment: "Event Alert section header"))
        tabContent.addSubview(eventHeaderLabel)

        // Event section description
        let eventDescription = createNoteLabel(NSLocalizedString("preferences.eventAlert.description", comment: "Event alert description"))
        tabContent.addSubview(eventDescription)

        // Sound selection row
        let alertSoundLabel = createLabel(NSLocalizedString("preferences.eventAlert.playSound", comment: "Play sound label"))
        tabContent.addSubview(alertSoundLabel)

        alertSoundPopup = createAlertSoundPopup()
        alertSoundPopup.setAccessibilityIdentifier("eventAlertSoundPopup")
        alertSoundPopup.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.alertSound", comment: "Event alert sound selection"))
        tabContent.addSubview(alertSoundPopup)

        // Duration row
        let eventStartSoundLabel = createLabel(NSLocalizedString("preferences.eventAlert.duration", comment: "Duration label"))
        tabContent.addSubview(eventStartSoundLabel)

        eventStartSoundPopup = createSoundDurationPopup(action: #selector(eventStartSoundChanged))
        eventStartSoundPopup.setAccessibilityIdentifier("eventAlertDurationPopup")
        eventStartSoundPopup.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.alertDuration", comment: "Event alert sound duration"))
        tabContent.addSubview(eventStartSoundPopup)

        // Warnings section header
        let warningsHeaderLabel = createSectionHeader(NSLocalizedString("preferences.warningAlerts.header", comment: "Warning Alerts section header"))
        tabContent.addSubview(warningsHeaderLabel)

        // Warnings section description
        let warningsDescription = createNoteLabel(NSLocalizedString("preferences.warningAlerts.description", comment: "Warning alerts description"))
        tabContent.addSubview(warningsDescription)

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
        warningsTableView.setAccessibilityIdentifier("warningsTable")
        warningsTableView.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.warningsTable", comment: "Warning alerts list"))

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = NSLocalizedString("preferences.warningAlerts.column.when", comment: "When column header")
        timeColumn.width = 105
        warningsTableView.addTableColumn(timeColumn)

        let soundColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sound"))
        soundColumn.title = NSLocalizedString("preferences.warningAlerts.column.playSound", comment: "Play Sound column header")
        soundColumn.width = 150
        warningsTableView.addTableColumn(soundColumn)

        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = NSLocalizedString("preferences.warningAlerts.column.duration", comment: "Duration column header")
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
        tabContent.addSubview(warningsScrollView)

        // Add warning button
        addWarningButton = NSButton(title: NSLocalizedString("preferences.warningAlerts.addButton", comment: "Add warning button"), target: self, action: #selector(addWarning))
        addWarningButton.translatesAutoresizingMaskIntoConstraints = false
        addWarningButton.bezelStyle = .rounded
        addWarningButton.controlSize = .small
        addWarningButton.setAccessibilityIdentifier("addWarningButton")
        addWarningButton.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.addWarning", comment: "Add a new warning alert"))
        tabContent.addSubview(addWarningButton)

        // Do Not Disturb section header
        let dndHeaderLabel = createSectionHeader(NSLocalizedString("preferences.dnd.header", comment: "Do Not Disturb section header"))
        tabContent.addSubview(dndHeaderLabel)

        // Respect DND checkbox
        respectDNDCheckbox = createCheckbox(title: NSLocalizedString("preferences.dnd.respectFocus", comment: "Respect DND checkbox"), action: #selector(respectDNDToggled))
        respectDNDCheckbox.setAccessibilityIdentifier("respectDNDCheckbox")
        tabContent.addSubview(respectDNDCheckbox)

        NSLayoutConstraint.activate([
            // Event header
            eventHeaderLabel.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            eventHeaderLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Event description
            eventDescription.topAnchor.constraint(equalTo: eventHeaderLabel.bottomAnchor, constant: 4),
            eventDescription.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Sound selection row
            alertSoundLabel.topAnchor.constraint(equalTo: eventDescription.bottomAnchor, constant: 12),
            alertSoundLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            alertSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            alertSoundPopup.centerYAnchor.constraint(equalTo: alertSoundLabel.centerYAnchor),
            alertSoundPopup.leadingAnchor.constraint(equalTo: alertSoundLabel.trailingAnchor, constant: 8),
            alertSoundPopup.widthAnchor.constraint(equalToConstant: 150),

            // Duration row
            eventStartSoundLabel.topAnchor.constraint(equalTo: alertSoundLabel.bottomAnchor, constant: 12),
            eventStartSoundLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            eventStartSoundLabel.widthAnchor.constraint(equalToConstant: 100),

            eventStartSoundPopup.centerYAnchor.constraint(equalTo: eventStartSoundLabel.centerYAnchor),
            eventStartSoundPopup.leadingAnchor.constraint(equalTo: eventStartSoundLabel.trailingAnchor, constant: 8),
            eventStartSoundPopup.widthAnchor.constraint(equalToConstant: 110),

            // Warnings header
            warningsHeaderLabel.topAnchor.constraint(equalTo: eventStartSoundLabel.bottomAnchor, constant: 24),
            warningsHeaderLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Warnings description
            warningsDescription.topAnchor.constraint(equalTo: warningsHeaderLabel.bottomAnchor, constant: 4),
            warningsDescription.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Warnings table view
            warningsScrollView.topAnchor.constraint(equalTo: warningsDescription.bottomAnchor, constant: 12),
            warningsScrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            warningsScrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            warningsScrollView.heightAnchor.constraint(equalToConstant: 144),

            // Add warning button
            addWarningButton.topAnchor.constraint(equalTo: warningsScrollView.bottomAnchor, constant: 8),
            addWarningButton.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Do Not Disturb header
            dndHeaderLabel.topAnchor.constraint(equalTo: addWarningButton.bottomAnchor, constant: 24),
            dndHeaderLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Respect DND checkbox
            respectDNDCheckbox.topAnchor.constraint(equalTo: dndHeaderLabel.bottomAnchor, constant: 12),
            respectDNDCheckbox.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        ])

        return tabContent
    }

    private func createCalendarTabContent() -> NSView {
        let tabContent = NSView()

        // Calendars section header
        let calendarsHeaderLabel = createSectionHeader(NSLocalizedString("preferences.calendars.header", comment: "Calendars section header"))
        tabContent.addSubview(calendarsHeaderLabel)

        // Calendars section description
        let calendarsDescription = createNoteLabel(NSLocalizedString("preferences.calendars.description", comment: "Calendars description"))
        tabContent.addSubview(calendarsDescription)

        // Calendars table view
        calendarsTableView = NSTableView()
        calendarsTableView.translatesAutoresizingMaskIntoConstraints = false
        calendarsTableView.dataSource = self
        calendarsTableView.delegate = self
        calendarsTableView.headerView = nil
        calendarsTableView.rowHeight = 24
        calendarsTableView.intercellSpacing = NSSize(width: 4, height: 2)
        calendarsTableView.gridStyleMask = []
        calendarsTableView.backgroundColor = .clear
        calendarsTableView.usesAlternatingRowBackgroundColors = false
        calendarsTableView.setAccessibilityIdentifier("calendarsTable")
        calendarsTableView.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.calendarsTable", comment: "Calendars list, select which calendars to monitor"))

        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
        checkboxColumn.width = 40
        calendarsTableView.addTableColumn(checkboxColumn)

        let calendarNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        calendarNameColumn.width = 400
        calendarsTableView.addTableColumn(calendarNameColumn)

        calendarsScrollView = NSScrollView()
        calendarsScrollView.translatesAutoresizingMaskIntoConstraints = false
        calendarsScrollView.documentView = calendarsTableView
        calendarsScrollView.hasVerticalScroller = true
        calendarsScrollView.hasHorizontalScroller = false
        calendarsScrollView.borderType = .bezelBorder
        calendarsScrollView.autohidesScrollers = true
        tabContent.addSubview(calendarsScrollView)

        // Warning label when no calendars are enabled
        noCalendarsLabel = createNoteLabel(NSLocalizedString("preferences.calendars.noCalendarsEnabled", comment: "No calendars enabled warning"))
        noCalendarsLabel.textColor = .systemOrange
        noCalendarsLabel.isHidden = true
        noCalendarsLabel.setAccessibilityIdentifier("noCalendarsWarning")
        tabContent.addSubview(noCalendarsLabel)

        NSLayoutConstraint.activate([
            // Calendars header
            calendarsHeaderLabel.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            calendarsHeaderLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Calendars description
            calendarsDescription.topAnchor.constraint(equalTo: calendarsHeaderLabel.bottomAnchor, constant: 4),
            calendarsDescription.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Calendars table view
            calendarsScrollView.topAnchor.constraint(equalTo: calendarsDescription.bottomAnchor, constant: 12),
            calendarsScrollView.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
            calendarsScrollView.trailingAnchor.constraint(equalTo: tabContent.trailingAnchor, constant: -16),
            calendarsScrollView.bottomAnchor.constraint(equalTo: noCalendarsLabel.topAnchor, constant: -8),

            // No calendars warning
            noCalendarsLabel.bottomAnchor.constraint(equalTo: tabContent.bottomAnchor, constant: -16),
            noCalendarsLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        ])

        return tabContent
    }

    private func createOtherTabContent() -> NSView {
        let tabContent = NSView()

        // General section header
        let generalHeaderLabel = createSectionHeader(NSLocalizedString("preferences.general.header", comment: "General section header"))
        tabContent.addSubview(generalHeaderLabel)

        // Launch at login checkbox
        launchAtLoginCheckbox = createCheckbox(title: NSLocalizedString("preferences.general.startAtLogin", comment: "Start at login checkbox"), action: #selector(launchAtLoginToggled))
        launchAtLoginCheckbox.setAccessibilityIdentifier("launchAtLoginCheckbox")
        tabContent.addSubview(launchAtLoginCheckbox)

        // Show window on launch checkbox
        showWindowOnLaunchCheckbox = createCheckbox(title: NSLocalizedString("preferences.general.showWelcome", comment: "Show welcome checkbox"), action: #selector(showWindowOnLaunchToggled))
        showWindowOnLaunchCheckbox.setAccessibilityIdentifier("showWelcomeCheckbox")
        tabContent.addSubview(showWindowOnLaunchCheckbox)

        NSLayoutConstraint.activate([
            // General header
            generalHeaderLabel.topAnchor.constraint(equalTo: tabContent.topAnchor, constant: 16),
            generalHeaderLabel.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Launch at login
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: generalHeaderLabel.bottomAnchor, constant: 12),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),

            // Show window on launch
            showWindowOnLaunchCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 8),
            showWindowOnLaunchCheckbox.leadingAnchor.constraint(equalTo: tabContent.leadingAnchor, constant: 16),
        ])

        return tabContent
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

    // MARK: - Calendar Management

    private func createCalendarCell(columnId: String, row: Int) -> NSView? {
        guard row < availableCalendars.count else { return nil }
        let calendar = availableCalendars[row]

        let cellView = NSView()

        switch columnId {
        case "checkbox":
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(calendarCheckboxToggled(_:)))
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkbox.state = Preferences.shared.isCalendarEnabled(calendar.calendarIdentifier) ? .on : .off
            checkbox.setAccessibilityIdentifier("calendarCheckbox_\(row)")
            checkbox.setAccessibilityLabel(String(format: NSLocalizedString("accessibility.preferences.calendarCheckbox", comment: "Enable or disable %@ calendar"), calendar.title))
            cellView.addSubview(checkbox)

            NSLayoutConstraint.activate([
                checkbox.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                checkbox.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])

        case "name":
            // Color circle
            let colorView = NSView()
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorView.wantsLayer = true
            colorView.layer?.cornerRadius = 6
            colorView.layer?.backgroundColor = calendar.color.cgColor
            cellView.addSubview(colorView)

            // Calendar title
            let label = NSTextField(labelWithString: calendar.title)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cellView.addSubview(label)

            NSLayoutConstraint.activate([
                colorView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                colorView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                colorView.widthAnchor.constraint(equalToConstant: 12),
                colorView.heightAnchor.constraint(equalToConstant: 12),

                label.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 6),
                label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor),
            ])

        default:
            break
        }

        return cellView
    }

    private func loadCalendars() {
        guard let eventStore = eventStore else { return }

        // Cleanup deleted calendars first
        Preferences.shared.cleanupDeletedCalendars(eventStore: eventStore)

        availableCalendars = eventStore.calendars(for: .event).sorted { $0.title < $1.title }
        calendarsTableView.reloadData()
        updateNoCalendarsWarning()
    }

    private func updateNoCalendarsWarning() {
        let enabledCount = availableCalendars.filter {
            Preferences.shared.isCalendarEnabled($0.calendarIdentifier)
        }.count
        noCalendarsLabel.isHidden = enabledCount > 0
    }

    @objc private func calendarCheckboxToggled(_ sender: NSButton) {
        let row = calendarsTableView.row(for: sender)
        guard row >= 0 && row < availableCalendars.count else { return }
        let calendar = availableCalendars[row]
        Preferences.shared.setCalendar(calendar.calendarIdentifier, enabled: sender.state == .on)
        updateNoCalendarsWarning()
    }

    // MARK: - Load/Save

    private func loadPreferences() {
        let prefs = Preferences.shared

        // Load warnings sorted by duration (longest first)
        warnings = prefs.warnings.sorted(by: { $0.minutesBefore > $1.minutesBefore })
        warningsTableView.reloadData()
        updateAddButtonState()

        // Select the current alert sound
        if let soundIndex = Preferences.availableSounds.firstIndex(where: { $0.id == prefs.alertSound }) {
            alertSoundPopup.selectItem(at: soundIndex)
        }

        selectSoundDuration(prefs.eventStartSoundDuration, in: eventStartSoundPopup)
        updateSoundControlsEnabled()

        launchAtLoginCheckbox.state = loginItemService.isEnabled ? .on : .off
        showWindowOnLaunchCheckbox.state = Preferences.shared.showWindowOnLaunch ? .on : .off
        respectDNDCheckbox.state = Preferences.shared.respectDoNotDisturb ? .on : .off

        // Load calendars
        eventStore = EKEventStore()
        loadCalendars()
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

    private func updateAddButtonState() {
        addWarningButton.isEnabled = warnings.count < 4
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
        guard warnings.count < 4 else { return }
        let prefs = Preferences.shared
        let newWarning = AlertWarning(
            minutesBefore: 5,
            sound: prefs.alertSound,
            soundDuration: prefs.eventStartSoundDuration
        )
        warnings.append(newWarning)
        warningsTableView.reloadData()
        updateAddButtonState()
        saveWarnings()
    }

    @objc private func removeWarning(_ sender: NSButton) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        warnings.remove(at: row)
        warningsTableView.reloadData()
        updateAddButtonState()
        saveWarnings()
    }

    @objc private func warningMinutesChanged(_ sender: NSStepper) {
        let row = warningsTableView.row(for: sender)
        guard row >= 0 && row < warnings.count else { return }
        warnings[row].minutesBefore = sender.integerValue
        // Update the text field in the same row (find the editable-looking text field)
        if let cellView = warningsTableView.view(atColumn: 0, row: row, makeIfNecessary: false) {
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
        if tableView == calendarsTableView {
            return availableCalendars.count
        } else {
            return warnings.count
        }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnId = tableColumn?.identifier.rawValue else { return nil }

        let cellView = NSView()

        if tableView == calendarsTableView {
            return createCalendarCell(columnId: columnId, row: row)
        }

        // Warnings table
        guard row < warnings.count else { return nil }
        let warning = warnings[row]

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
            let minLabel = NSTextField(labelWithString: NSLocalizedString("preferences.warningAlerts.minBeforeEvent", comment: "min before event label"))
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
            if let trashImage = NSImage(systemSymbolName: "trash", accessibilityDescription: NSLocalizedString("accessibility.preferences.removeWarning", comment: "Remove warning")) {
                button.image = trashImage
            }
            button.imagePosition = .imageOnly
            button.setAccessibilityIdentifier("removeWarningButton")
            button.setAccessibilityLabel(NSLocalizedString("accessibility.preferences.removeWarning", comment: "Remove this warning alert"))
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
                // Uses enableLaunchAtLogin which checks status first to prevent duplicates
                try loginItemService.enableLaunchAtLogin()
            } else {
                try loginItemService.disableLaunchAtLogin()
            }
        } catch {
            // Revert checkbox state on error
            launchAtLoginCheckbox.state = launchAtLoginCheckbox.state == .on ? .off : .on
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("loginItem.error.title", comment: "Login item error title")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func showWindowOnLaunchToggled() {
        Preferences.shared.showWindowOnLaunch = showWindowOnLaunchCheckbox.state == .on
    }

    @objc private func respectDNDToggled() {
        Preferences.shared.respectDoNotDisturb = respectDNDCheckbox.state == .on
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
