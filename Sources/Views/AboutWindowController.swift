import AppKit

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "About Klaxon"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupContent()
        centerOnMainScreen()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 380))

        // App icon
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(x: (400 - iconSize) / 2, y: 280, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App name
        let appNameLabel = NSTextField(labelWithString: "Klaxon")
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 20)
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 20, y: 245, width: 360, height: 28)
        contentView.addSubview(appNameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 20, y: 225, width: 360, height: 18)
        contentView.addSubview(versionLabel)

        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Klaxon watches your calendar and sounds the alarm when meetings are about to start. Never miss a meeting again!")
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.alignment = .center
        descriptionLabel.frame = NSRect(x: 30, y: 175, width: 340, height: 45)
        contentView.addSubview(descriptionLabel)

        // Assistive purpose
        let assistiveLabel = NSTextField(wrappingLabelWithString: "Designed as an assistive tool for people with ADHD, time blindness, or anyone who gets absorbed in their work and needs an unmissable reminder.")
        assistiveLabel.font = NSFont.systemFont(ofSize: 11)
        assistiveLabel.alignment = .center
        assistiveLabel.textColor = .secondaryLabelColor
        assistiveLabel.frame = NSRect(x: 30, y: 120, width: 340, height: 50)
        contentView.addSubview(assistiveLabel)

        // Author
        let authorLabel = NSTextField(labelWithString: "Created by Michael L. Welles")
        authorLabel.font = NSFont.systemFont(ofSize: 11)
        authorLabel.alignment = .center
        authorLabel.frame = NSRect(x: 20, y: 95, width: 360, height: 16)
        contentView.addSubview(authorLabel)

        let emailLabel = createClickableEmail()
        emailLabel.frame = NSRect(x: 20, y: 77, width: 360, height: 16)
        contentView.addSubview(emailLabel)

        // Credits header
        let creditsHeader = NSTextField(labelWithString: "Credits")
        creditsHeader.font = NSFont.boldSystemFont(ofSize: 11)
        creditsHeader.alignment = .center
        creditsHeader.frame = NSRect(x: 20, y: 55, width: 360, height: 16)
        contentView.addSubview(creditsHeader)

        // Icon credit
        let iconCredit = NSTextField(labelWithString: "Icon: Electric Bell by Firkin (CC0, OpenClipart)")
        iconCredit.font = NSFont.systemFont(ofSize: 10)
        iconCredit.alignment = .center
        iconCredit.textColor = .secondaryLabelColor
        iconCredit.frame = NSRect(x: 20, y: 38, width: 360, height: 14)
        contentView.addSubview(iconCredit)

        // Sound credit
        let soundCredit = NSTextField(labelWithString: "Sound: Fire Alarm by battlestar10 (CC BY 3.0, SoundBible)")
        soundCredit.font = NSFont.systemFont(ofSize: 10)
        soundCredit.alignment = .center
        soundCredit.textColor = .secondaryLabelColor
        soundCredit.frame = NSRect(x: 20, y: 22, width: 360, height: 14)
        contentView.addSubview(soundCredit)

        window?.contentView = contentView
    }

    private func createClickableEmail() -> NSTextField {
        let emailField = NSTextField(frame: .zero)
        emailField.isEditable = false
        emailField.isBordered = false
        emailField.backgroundColor = .clear
        emailField.allowsEditingTextAttributes = true
        emailField.isSelectable = true
        emailField.alignment = .center

        let email = "michael@welles.nyc"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.linkColor,
            .link: URL(string: "mailto:\(email)")!,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        emailField.attributedStringValue = NSAttributedString(string: email, attributes: attributes)

        return emailField
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
    }
}
