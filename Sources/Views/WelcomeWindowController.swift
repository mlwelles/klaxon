import AppKit

final class WelcomeWindowController: NSWindowController {
    private var onDismiss: (() -> Void)?

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Klaxon"
        window.center()

        super.init(window: window)

        setupContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        guard let window = window else { return }

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 320))

        // App icon
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(x: (400 - iconSize) / 2, y: 220, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App title
        let titleLabel = NSTextField(labelWithString: "Klaxon")
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 185, width: 360, height: 30)
        contentView.addSubview(titleLabel)

        // Copyright
        let year = Calendar.current.component(.year, from: Date())
        let copyrightLabel = NSTextField(labelWithString: "© \(year) Michael L. Welles")
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.frame = NSRect(x: 20, y: 167, width: 360, height: 16)
        contentView.addSubview(copyrightLabel)

        // Explanation text
        let explanationText = """
        Klaxon monitors your calendar and sounds an unmissable alarm when meetings are about to start.

        Once you dismiss this window, Klaxon will keep running in the background. Look for the bell icon in your menu bar to access preferences and controls.
        """
        let explanationLabel = NSTextField(wrappingLabelWithString: explanationText)
        explanationLabel.font = .systemFont(ofSize: 13)
        explanationLabel.alignment = .center
        explanationLabel.frame = NSRect(x: 30, y: 55, width: 340, height: 120)
        contentView.addSubview(explanationLabel)

        // OK button
        let okButton = NSButton(title: "OK", target: self, action: #selector(okPressed))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.frame = NSRect(x: 155, y: 15, width: 90, height: 32)
        contentView.addSubview(okButton)

        window.contentView = contentView
    }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func okPressed() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
        onDismiss?()
    }
}
