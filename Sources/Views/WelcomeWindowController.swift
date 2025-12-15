import AppKit

final class WelcomeWindowController: NSWindowController {
    private var onDismiss: (() -> Void)?
    private var onOpenPreferences: (() -> Void)?

    init(onDismiss: @escaping () -> Void, onOpenPreferences: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.onOpenPreferences = onOpenPreferences

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

        // Preferences button
        let prefsButton = NSButton(title: "Preferences", target: self, action: #selector(preferencesPressed))
        prefsButton.bezelStyle = .rounded
        prefsButton.frame = NSRect(x: 105, y: 15, width: 95, height: 32)
        contentView.addSubview(prefsButton)

        // Dismiss button
        let dismissButton = NSButton(title: "Dismiss", target: self, action: #selector(dismissPressed))
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\r"
        dismissButton.frame = NSRect(x: 205, y: 15, width: 90, height: 32)
        contentView.addSubview(dismissButton)

        window.contentView = contentView
    }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func dismissPressed() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
        onDismiss?()
    }

    @objc private func preferencesPressed() {
        window?.close()
        NSApp.setActivationPolicy(.accessory)
        onDismiss?()
        onOpenPreferences?()
    }
}
