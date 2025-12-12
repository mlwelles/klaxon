import AppKit
import AVFoundation
import EventKit

final class AlertWindowController: NSWindowController {
    private let event: EKEvent
    private let alertType: AlertType
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?

    init(event: EKEvent, alertType: AlertType = .secondWarning(minutes: 1)) {
        self.event = event
        self.alertType = alertType

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = Self.windowTitle(for: alertType)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupContent()
        centerOnMainScreen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func windowTitle(for alertType: AlertType) -> String {
        switch alertType {
        case .firstWarning(let minutes), .secondWarning(let minutes):
            return "\(minutes) Minute Warning"
        case .eventStarting:
            return "Event Starting Now"
        }
    }

    private func alertMessage(for alertType: AlertType) -> String {
        switch alertType {
        case .firstWarning(let minutes), .secondWarning(let minutes):
            return "starts in \(minutes) minute\(minutes == 1 ? "" : "s")"
        case .eventStarting:
            return "is starting now!"
        }
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 220))

        // Left 1/3: App icon
        let iconSize: CGFloat = 120
        let iconView = NSImageView(frame: NSRect(x: 25, y: (220 - iconSize) / 2 + 10, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // Right 2/3: Event details
        let rightX: CGFloat = 160
        let rightWidth: CGFloat = 320

        // Event title
        let eventTitle = event.title?.isEmpty == false ? event.title! : "Untitled Event"
        let titleLabel = NSTextField(labelWithString: eventTitle)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .left
        titleLabel.frame = NSRect(x: rightX, y: 170, width: rightWidth, height: 24)
        contentView.addSubview(titleLabel)

        // Alert message
        let messageLabel = NSTextField(labelWithString: alertMessage(for: alertType))
        messageLabel.font = NSFont.systemFont(ofSize: 14)
        messageLabel.alignment = .left
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.frame = NSRect(x: rightX, y: 145, width: rightWidth, height: 20)
        contentView.addSubview(messageLabel)

        // Start time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .medium
        let timeString = timeFormatter.string(from: event.startDate)

        let timeLabel = NSTextField(labelWithString: "Start: \(timeString)")
        timeLabel.font = NSFont.systemFont(ofSize: 12)
        timeLabel.alignment = .left
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.frame = NSRect(x: rightX, y: 120, width: rightWidth, height: 18)
        contentView.addSubview(timeLabel)

        // Location
        if let location = event.location, !location.isEmpty {
            let locationLabel = NSTextField(labelWithString: "Location: \(location)")
            locationLabel.font = NSFont.systemFont(ofSize: 11)
            locationLabel.alignment = .left
            locationLabel.textColor = .secondaryLabelColor
            locationLabel.frame = NSRect(x: rightX, y: 95, width: rightWidth, height: 16)
            contentView.addSubview(locationLabel)
        }

        // URL (clickable)
        if let url = event.url {
            let urlTextView = createClickableLink(url: url, frame: NSRect(x: rightX, y: 70, width: rightWidth, height: 16))
            contentView.addSubview(urlTextView)
        }

        // Buttons
        let dismissButton = NSButton(title: "Dismiss", target: self, action: #selector(dismissAlert))
        dismissButton.bezelStyle = .rounded
        dismissButton.frame = NSRect(x: 390, y: 15, width: 90, height: 32)
        dismissButton.keyEquivalent = "\u{1b}" // Escape key
        contentView.addSubview(dismissButton)

        let openEventButton = NSButton(title: "Open Event", target: self, action: #selector(openEvent))
        openEventButton.bezelStyle = .rounded
        openEventButton.frame = NSRect(x: 280, y: 15, width: 100, height: 32)
        openEventButton.keyEquivalent = "\r" // Enter key
        contentView.addSubview(openEventButton)

        window?.contentView = contentView
    }

    private func createClickableLink(url: URL, frame: NSRect) -> NSTextField {
        let linkField = NSTextField(frame: frame)
        linkField.isEditable = false
        linkField.isBordered = false
        linkField.backgroundColor = .clear
        linkField.allowsEditingTextAttributes = true
        linkField.isSelectable = true

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.linkColor,
            .link: url,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        linkField.attributedStringValue = NSAttributedString(string: url.absoluteString, attributes: attributes)

        return linkField
    }

    private func centerOnMainScreen() {
        guard let screen = NSScreen.main, let window = window else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        playAlertSound()
    }

    private func playAlertSound() {
        let duration = audioDuration(for: alertType)
        guard duration > 0 else { return }

        let soundName = Preferences.shared.alertSound
        guard !soundName.isEmpty else { return }

        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            // Schedule stop based on alert type
            audioStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stopAlertSound()
            }
        } catch {
            // Silently fail if audio playback fails
        }
    }

    private func audioDuration(for alertType: AlertType) -> TimeInterval {
        let prefs = Preferences.shared
        switch alertType {
        case .firstWarning:
            return prefs.firstAlertSoundDuration
        case .secondWarning:
            return prefs.secondAlertSoundDuration
        case .eventStarting:
            return prefs.eventStartSoundDuration
        }
    }

    private func stopAlertSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioStopTimer?.invalidate()
        audioStopTimer = nil
    }

    @objc private func dismissAlert() {
        stopAlertSound()
        close()
    }

    @objc private func openEvent() {
        stopAlertSound()
        // Build the Calendar.app URL to open the specific event
        // Format: ical://ekevent/<calendarItemExternalIdentifier>?start=<date>
        if let eventIdentifier = event.calendarItemExternalIdentifier {
            let dateFormatter = ISO8601DateFormatter()
            let startDateString = dateFormatter.string(from: event.startDate)

            // Try the ical URL scheme first
            if let url = URL(string: "ical://ekevent/\(eventIdentifier)?start=\(startDateString)") {
                NSWorkspace.shared.open(url)
            } else {
                // Fallback: just open Calendar.app
                NSWorkspace.shared.open(URL(string: "ical://")!)
            }
        } else {
            // Fallback: just open Calendar.app
            NSWorkspace.shared.open(URL(string: "ical://")!)
        }
        close()
    }
}
