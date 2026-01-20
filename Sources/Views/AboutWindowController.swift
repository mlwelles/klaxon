import AppKit

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = NSLocalizedString("about.title", comment: "About window title")
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
        let appNameLabel = NSTextField(labelWithString: NSLocalizedString("app.name", comment: "App name"))
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 20)
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 20, y: 345, width: 360, height: 28)
        contentView.addSubview(appNameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: String(format: NSLocalizedString("about.version", comment: "Version %@"), version))
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
        let descriptionLabel = createCenteredWrappingLabel(
            text: NSLocalizedString("about.description", comment: "About description"),
            fontSize: 12,
            textColor: .labelColor
        )
        descriptionLabel.frame = NSRect(x: 30, y: 232, width: 340, height: 45)
        contentView.addSubview(descriptionLabel)

        // Assistive purpose
        let assistiveLabel = createCenteredWrappingLabel(
            text: NSLocalizedString("about.assistive", comment: "Assistive purpose description"),
            fontSize: 11,
            textColor: .secondaryLabelColor
        )
        assistiveLabel.frame = NSRect(x: 30, y: 177, width: 340, height: 50)
        contentView.addSubview(assistiveLabel)

        // Credits header
        let creditsHeader = NSTextField(labelWithString: NSLocalizedString("about.credits.header", comment: "Credits header"))
        creditsHeader.font = NSFont.boldSystemFont(ofSize: 11)
        creditsHeader.alignment = .center
        creditsHeader.frame = NSRect(x: 20, y: 152, width: 360, height: 16)
        contentView.addSubview(creditsHeader)

        // Icon credit
        let iconCredit = NSTextField(labelWithString: NSLocalizedString("about.credits.icon", comment: "Icon credit"))
        iconCredit.font = NSFont.systemFont(ofSize: 10)
        iconCredit.alignment = .center
        iconCredit.textColor = .secondaryLabelColor
        iconCredit.frame = NSRect(x: 20, y: 135, width: 360, height: 14)
        contentView.addSubview(iconCredit)

        // Sound credits
        let soundCredits = [
            NSLocalizedString("about.credits.sound1", comment: "Sound credit 1"),
            NSLocalizedString("about.credits.sound2", comment: "Sound credit 2"),
            NSLocalizedString("about.credits.sound3", comment: "Sound credit 3"),
            NSLocalizedString("about.credits.sound4", comment: "Sound credit 4")
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

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let year = Calendar.current.component(.year, from: Date())
        let fullText = String(format: NSLocalizedString("about.copyright", comment: "© %d Michael L. Welles (@mlwelles)"), year)
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .paragraphStyle: paragraphStyle
            ]
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

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let fullText = NSLocalizedString("about.license", comment: "Released under the MIT License as open source.")
        let attributedString = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
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

    private func createCenteredWrappingLabel(text: String, fontSize: CGFloat, textColor: NSColor) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isEditable = false
        field.isBordered = false
        field.backgroundColor = .clear
        field.isSelectable = false

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

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
