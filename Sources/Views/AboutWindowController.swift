import AppKit

// Flipped view so scroll view content starts at top
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 580),
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
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 580
        let contentWidth: CGFloat = 360
        let buttonAreaHeight: CGFloat = 50

        // Create stack view for auto-sizing content
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // App icon (centered)
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setAccessibilityLabel(NSLocalizedString("app.name", comment: "App name") + " icon")
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: contentWidth)
        ])
        stackView.addArrangedSubview(iconContainer)

        // App name
        stackView.addArrangedSubview(createLabel(
            text: NSLocalizedString("app.name", comment: "App name"),
            fontSize: 20, bold: true, width: contentWidth
        ))

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        stackView.addArrangedSubview(createLabel(
            text: String(format: NSLocalizedString("about.version", comment: "Version %@"), version),
            fontSize: 12, textColor: .secondaryLabelColor, width: contentWidth
        ))

        // Copyright with GitHub link
        let baseCopyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright © 2026 Michael L. Welles."
        let copyrightText = baseCopyright.replacingOccurrences(of: " All rights reserved.", with: "") + " (@mlwelles)"
        stackView.addArrangedSubview(createLinkLabel(
            text: copyrightText,
            linkText: "(@mlwelles)",
            url: URL(string: "https://github.com/mlwelles")!,
            fontSize: 11, width: contentWidth
        ))

        // MIT License link
        let licenseLink = createLinkLabel(
            text: NSLocalizedString("about.license", comment: "Released under the MIT License as open source."),
            linkText: "MIT License",
            url: URL(string: "https://github.com/mlwelles/klaxon/blob/main/LICENSE")!,
            fontSize: 11, textColor: .secondaryLabelColor, width: contentWidth
        )
        stackView.addArrangedSubview(licenseLink)
        stackView.setCustomSpacing(15, after: licenseLink)

        // Description
        stackView.addArrangedSubview(createWrappingLabel(
            text: NSLocalizedString("about.description", comment: "About description"),
            fontSize: 12, width: contentWidth - 40
        ))

        // Assistive purpose
        let assistiveLabel = createWrappingLabel(
            text: NSLocalizedString("about.assistive", comment: "Assistive purpose description"),
            fontSize: 11, textColor: .secondaryLabelColor, width: contentWidth - 40
        )
        stackView.addArrangedSubview(assistiveLabel)
        stackView.setCustomSpacing(15, after: assistiveLabel)

        // Credits header
        stackView.addArrangedSubview(createLabel(
            text: NSLocalizedString("about.credits.header", comment: "Credits header"),
            fontSize: 11, bold: true, width: contentWidth
        ))

        // Credits as bullet list
        let credits = [
            NSLocalizedString("about.credits.icon", comment: "Icon credit"),
            NSLocalizedString("about.credits.sound1", comment: "Sound credit 1"),
            NSLocalizedString("about.credits.sound2", comment: "Sound credit 2"),
            NSLocalizedString("about.credits.sound3", comment: "Sound credit 3"),
            NSLocalizedString("about.credits.sound4", comment: "Sound credit 4")
        ]
        let creditsLabel = createWrappingLabel(
            text: credits.map { "• \($0)" }.joined(separator: "\n"),
            fontSize: 9, textColor: .secondaryLabelColor, width: contentWidth - 10
        )
        stackView.addArrangedSubview(creditsLabel)
        stackView.setCustomSpacing(20, after: creditsLabel)

        // License section header
        stackView.addArrangedSubview(createLabel(
            text: NSLocalizedString("about.license.header", comment: "License header"),
            fontSize: 11, bold: true, width: contentWidth
        ))

        // License text
        stackView.addArrangedSubview(createWrappingLabel(
            text: loadLicenseText(),
            fontSize: 9, textColor: .secondaryLabelColor, width: contentWidth - 40
        ))

        // Wrap stack view in a flipped view for proper scroll orientation
        let flippedView = FlippedView()
        flippedView.translatesAutoresizingMaskIntoConstraints = false
        flippedView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: flippedView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: flippedView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: flippedView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: flippedView.bottomAnchor),
            stackView.widthAnchor.constraint(equalToConstant: windowWidth)
        ])

        // Create main content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        // Create scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: buttonAreaHeight, width: windowWidth, height: windowHeight - buttonAreaHeight))
        scrollView.documentView = flippedView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)

        // Let Auto Layout calculate the size, then scroll to top
        flippedView.layoutSubtreeIfNeeded()
        scrollView.documentView?.scroll(.zero)

        // OK button at bottom
        let okButton = NSButton(title: NSLocalizedString("preferences.button.ok", comment: "OK"), target: self, action: #selector(dismissWindow))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.frame = NSRect(x: (windowWidth - 80) / 2, y: 12, width: 80, height: 28)
        okButton.setAccessibilityIdentifier("okButton")
        okButton.setAccessibilityLabel(NSLocalizedString("accessibility.about.okButton", comment: "OK, close About window"))
        contentView.addSubview(okButton)

        window?.contentView = contentView
    }

    @objc private func dismissWindow() {
        window?.close()
    }

    // MARK: - Helper Functions

    private func loadLicenseText() -> String {
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            // Clean up formatting: preserve paragraph breaks, remove line breaks within paragraphs
            let paragraphs = text.components(separatedBy: "\n\n")
            let cleanedParagraphs = paragraphs.map { $0.replacingOccurrences(of: "\n", with: " ") }
            return cleanedParagraphs.joined(separator: "\n\n")
        }
        return "MIT License\n\nSee LICENSE file for full terms."
    }

    /// Creates a simple single-line label with consistent styling
    private func createLabel(
        text: String,
        fontSize: CGFloat,
        bold: Bool = false,
        textColor: NSColor = .labelColor,
        width: CGFloat,
        accessibilityId: String? = nil
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        field.alignment = .left
        field.textColor = textColor
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        if let id = accessibilityId {
            field.setAccessibilityIdentifier(id)
        }
        return field
    }

    /// Creates a multi-line wrapping label with consistent styling
    private func createWrappingLabel(
        text: String,
        fontSize: CGFloat,
        textColor: NSColor = .labelColor,
        width: CGFloat,
        accessibilityId: String? = nil
    ) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = NSFont.systemFont(ofSize: fontSize)
        field.textColor = textColor
        field.alignment = .left
        field.isSelectable = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        if let id = accessibilityId {
            field.setAccessibilityIdentifier(id)
        }
        return field
    }

    /// Creates a label with a clickable link portion
    private func createLinkLabel(
        text: String,
        linkText: String,
        url: URL,
        fontSize: CGFloat,
        textColor: NSColor = .labelColor,
        width: CGFloat,
        accessibilityId: String? = nil,
        accessibilityLabel: String? = nil
    ) -> NSTextField {
        let field = NSTextField(frame: .zero)
        field.isEditable = false
        field.isBordered = false
        field.backgroundColor = .clear
        field.allowsEditingTextAttributes = true
        field.isSelectable = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        if let range = text.range(of: linkText) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttributes([
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: nsRange)
        }

        field.attributedStringValue = attributedString

        if let id = accessibilityId {
            field.setAccessibilityIdentifier(id)
        }
        if let label = accessibilityLabel {
            field.setAccessibilityLabel(label)
        }
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
