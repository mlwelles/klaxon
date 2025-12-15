import AppKit

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
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
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 480))

        // App icon
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(x: (400 - iconSize) / 2, y: 380, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App name
        let appNameLabel = NSTextField(labelWithString: "Klaxon")
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 20)
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 20, y: 345, width: 360, height: 28)
        contentView.addSubview(appNameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 20, y: 325, width: 360, height: 18)
        contentView.addSubview(versionLabel)

        // Copyright with GitHub link
        let copyrightLabel = createCopyrightLabel()
        copyrightLabel.frame = NSRect(x: 20, y: 305, width: 360, height: 16)
        contentView.addSubview(copyrightLabel)

        // MIT License link
        let licenseLabel = createLicenseLabel()
        licenseLabel.frame = NSRect(x: 20, y: 287, width: 360, height: 16)
        contentView.addSubview(licenseLabel)

        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Klaxon watches your calendar and sounds the alarm when meetings are about to start. Never miss a meeting again!")
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.alignment = .center
        descriptionLabel.frame = NSRect(x: 30, y: 232, width: 340, height: 45)
        contentView.addSubview(descriptionLabel)

        // Assistive purpose
        let assistiveLabel = NSTextField(wrappingLabelWithString: "Designed as an assistive tool for people with ADHD, time blindness, or anyone who gets absorbed in their work and needs an unmissable reminder.")
        assistiveLabel.font = NSFont.systemFont(ofSize: 11)
        assistiveLabel.alignment = .center
        assistiveLabel.textColor = .secondaryLabelColor
        assistiveLabel.frame = NSRect(x: 30, y: 177, width: 340, height: 50)
        contentView.addSubview(assistiveLabel)

        // Credits header
        let creditsHeader = NSTextField(labelWithString: "Credits")
        creditsHeader.font = NSFont.boldSystemFont(ofSize: 11)
        creditsHeader.alignment = .center
        creditsHeader.frame = NSRect(x: 20, y: 152, width: 360, height: 16)
        contentView.addSubview(creditsHeader)

        // Icon credit
        let iconCredit = NSTextField(labelWithString: "Icon: Electric Bell by Firkin (CC0, OpenClipart)")
        iconCredit.font = NSFont.systemFont(ofSize: 10)
        iconCredit.alignment = .center
        iconCredit.textColor = .secondaryLabelColor
        iconCredit.frame = NSRect(x: 20, y: 135, width: 360, height: 14)
        contentView.addSubview(iconCredit)

        // Sound credits
        let soundCredits = [
            "Fire Alarm Bell by battlestar10 (CC BY 3.0, SoundBible)",
            "Air Horn, Red Alert, School Fire Alarm (Public Domain, SoundBible)",
            "Alarm Tone, Alert Bells, Battleship Alarm (Mixkit License, Mixkit)",
            "Classic Alarm, Urgent Tone, Warning Buzzer (Mixkit License, Mixkit)"
        ]

        var yPosition: CGFloat = 118
        for credit in soundCredits {
            let creditLabel = NSTextField(labelWithString: credit)
            creditLabel.font = NSFont.systemFont(ofSize: 9)
            creditLabel.alignment = .center
            creditLabel.textColor = .secondaryLabelColor
            creditLabel.frame = NSRect(x: 20, y: yPosition, width: 360, height: 14)
            contentView.addSubview(creditLabel)
            yPosition -= 15
        }

        window?.contentView = contentView
    }

    private func createCopyrightLabel() -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isEditable = false
        field.isBordered = false
        field.backgroundColor = .clear
        field.allowsEditingTextAttributes = true
        field.isSelectable = true
        field.alignment = .center

        let year = Calendar.current.component(.year, from: Date())
        let fullText = "© \(year) Michael L. Welles (@mlwelles)"
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )

        // Make (@mlwelles) a clickable link
        if let range = fullText.range(of: "(@mlwelles)") {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttributes([
                .link: URL(string: "https://github.com/mlwelles")!,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: nsRange)
        }

        field.attributedStringValue = attributedString
        return field
    }

    private func createLicenseLabel() -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isEditable = false
        field.isBordered = false
        field.backgroundColor = .clear
        field.allowsEditingTextAttributes = true
        field.isSelectable = true
        field.alignment = .center

        let fullText = "Released under the MIT License as open source."
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        // Make "MIT License" a clickable link
        if let range = fullText.range(of: "MIT License") {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttributes([
                .link: URL(string: "https://github.com/mlwelles/klaxon/blob/main/LICENSE.md")!,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: nsRange)
        }

        field.attributedStringValue = attributedString
        return field
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
