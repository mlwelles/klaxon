import AppKit

final class WelcomeWindowController: NSWindowController {
    private var onDismiss: (() -> Void)?

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
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

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))

        // App icon
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(x: (400 - iconSize) / 2, y: 180, width: iconSize, height: iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App title
        let titleLabel = NSTextField(labelWithString: "Klaxon")
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 145, width: 360, height: 30)
        contentView.addSubview(titleLabel)

        // Explanation text
        let explanationText = """
        Klaxon needs access to your calendar to monitor upcoming events and alert you before they start.

        When you click OK, macOS will ask you to grant calendar access.
        """
        let explanationLabel = NSTextField(wrappingLabelWithString: explanationText)
        explanationLabel.font = .systemFont(ofSize: 13)
        explanationLabel.alignment = .center
        explanationLabel.frame = NSRect(x: 30, y: 55, width: 340, height: 80)
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
