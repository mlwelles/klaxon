import AppKit
import AVFoundation
import EventKit

final class AlertWindowController: NSWindowController {
    private let event: EKEvent
    private let alertType: AlertType
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTimer: Timer?
    private var joinURL: URL?

    init(event: EKEvent, alertType: AlertType = .warning(minutes: 1, sound: "fire-alarm-bell", soundDuration: 4.0)) {
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
        case .warning(let minutes, _, _):
            return String(format: NSLocalizedString("alert.warning.title", comment: "%d Minute Warning"), minutes)
        case .eventStarting:
            return NSLocalizedString("alert.starting.title", comment: "Event Starting Now")
        }
    }

    private func alertMessage(for alertType: AlertType) -> String {
        switch alertType {
        case .warning(let minutes, _, _):
            if minutes == 1 {
                return String(format: NSLocalizedString("alert.warning.message", comment: "starts in %d minute"), minutes)
            } else {
                return String(format: NSLocalizedString("alert.warning.messagePlural", comment: "starts in %d minutes"), minutes)
            }
        case .eventStarting:
            return NSLocalizedString("alert.starting.message", comment: "is starting now!")
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
        let eventTitle = event.title?.isEmpty == false ? event.title! : NSLocalizedString("alert.untitledEvent", comment: "Untitled Event")
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

        let timeLabel = NSTextField(labelWithString: String(format: NSLocalizedString("alert.startTime", comment: "Start: %@"), timeString))
        timeLabel.font = NSFont.systemFont(ofSize: 12)
        timeLabel.alignment = .left
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.frame = NSRect(x: rightX, y: 120, width: rightWidth, height: 18)
        contentView.addSubview(timeLabel)

        // Location
        if let location = event.location, !location.isEmpty {
            let locationLabel = NSTextField(labelWithString: String(format: NSLocalizedString("alert.location", comment: "Location: %@"), location))
            locationLabel.font = NSFont.systemFont(ofSize: 11)
            locationLabel.alignment = .left
            locationLabel.textColor = .secondaryLabelColor
            locationLabel.frame = NSRect(x: rightX, y: 95, width: rightWidth, height: 16)
            contentView.addSubview(locationLabel)
        }

        // Join link (clickable) - check event.url and notes for video conference links
        joinURL = findJoinLink()
        if let url = joinURL {
            let urlTextView = createClickableLink(url: url, frame: NSRect(x: rightX, y: 70, width: rightWidth, height: 16))
            contentView.addSubview(urlTextView)
        }

        // Buttons - always show all three
        let dismissButton = NSButton(title: NSLocalizedString("alert.button.dismiss", comment: "Dismiss button"), target: self, action: #selector(dismissAlert))
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}" // Escape key
        dismissButton.frame = NSRect(x: 390, y: 15, width: 90, height: 32)
        contentView.addSubview(dismissButton)

        let openEventButton = NSButton(title: NSLocalizedString("alert.button.openEvent", comment: "Open Event button"), target: self, action: #selector(openEvent))
        openEventButton.bezelStyle = .rounded
        openEventButton.frame = NSRect(x: 275, y: 15, width: 105, height: 32)
        contentView.addSubview(openEventButton)

        let joinButton = NSButton(title: NSLocalizedString("alert.button.join", comment: "Join button"), target: self, action: #selector(joinMeeting))
        joinButton.bezelStyle = .rounded
        joinButton.frame = NSRect(x: 160, y: 15, width: 105, height: 32)
        contentView.addSubview(joinButton)

        // Set enabled state based on join link availability
        if joinURL == nil {
            joinButton.isEnabled = false
        }

        // Enter: Join Meeting (if available) or Open Event
        // Escape: Dismiss (handled via cancelOperation)
        if joinURL != nil {
            joinButton.keyEquivalent = "\r"
        } else {
            openEventButton.keyEquivalent = "\r"
        }

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

    /// Extracts a video conference join link from the event
    /// Checks event.url first, then searches notes for common meeting URLs
    private func findJoinLink() -> URL? {
        // Check event.url first
        if let url = event.url {
            if isVideoConferenceURL(url) {
                return url
            }
        }

        // Search in notes/description for video conference links
        if let notes = event.notes, !notes.isEmpty {
            if let url = extractVideoConferenceURL(from: notes) {
                return url
            }
        }

        // Fall back to event.url even if not a recognized video conference
        return event.url
    }

    private func isVideoConferenceURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let videoConferenceHosts = [
            "zoom.us", "zoom.com",
            "meet.google.com",
            "teams.microsoft.com", "teams.live.com",
            "webex.com",
            "gotomeeting.com", "gotomeet.me",
            "bluejeans.com",
            "whereby.com",
            "around.co",
            "meet.jit.si",
            "slack.com"  // Slack huddles
        ]
        return videoConferenceHosts.contains { host.contains($0) }
    }

    private func extractVideoConferenceURL(from text: String) -> URL? {
        // Patterns for common video conference URLs
        let patterns = [
            "https://[\\w.-]*zoom\\.us/j/[\\w?=&-]+",
            "https://[\\w.-]*zoom\\.com/j/[\\w?=&-]+",
            "https://meet\\.google\\.com/[\\w-]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[\\w%/-]+",
            "https://teams\\.live\\.com/meet/[\\w-]+",
            "https://[\\w.-]*webex\\.com/[\\w/.-]+",
            "https://[\\w.-]*gotomeeting\\.com/join/[\\w-]+",
            "https://[\\w.-]*gotomeet\\.me/[\\w-]+",
            "https://[\\w.-]*bluejeans\\.com/[\\w/-]+",
            "https://whereby\\.com/[\\w-]+",
            "https://meet\\.jit\\.si/[\\w-]+"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let matchRange = Range(match.range, in: text) {
                        let urlString = String(text[matchRange])
                        if let url = URL(string: urlString) {
                            return url
                        }
                    }
                }
            }
        }

        return nil
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

    private func fadeOutDuration(for duration: Double) -> TimeInterval {
        if duration >= 2 { return 0.5 }
        return 0  // No fade for 1 second or less
    }

    private func playAlertSound() {
        let (soundName, duration) = soundSettings(for: alertType)
        guard duration > 0, !soundName.isEmpty else { return }

        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
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

    private func soundSettings(for alertType: AlertType) -> (sound: String, duration: TimeInterval) {
        switch alertType {
        case .warning(_, let sound, let soundDuration):
            return (sound, soundDuration)
        case .eventStarting:
            return (Preferences.shared.alertSound, Preferences.shared.eventStartSoundDuration)
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

    // Handle Escape key to dismiss (since Enter may override the button's Escape key equivalent)
    override func cancelOperation(_ sender: Any?) {
        dismissAlert()
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

    @objc private func joinMeeting() {
        stopAlertSound()
        if let url = joinURL {
            NSWorkspace.shared.open(url)
        }
        close()
    }
}
