import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    private static let signature: OSType = 0x4c4f4646

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var definition: HotKeyDefinition
    private let action: () -> Void

    init?(definition: HotKeyDefinition, action: @escaping () -> Void) {
        self.definition = definition
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                hotKey.action()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            return nil
        }

        guard register(definition) else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
            }
            return nil
        }
    }

    func update(definition: HotKeyDefinition) -> Bool {
        unregisterHotKey()

        if register(definition) {
            self.definition = definition
            return true
        }

        _ = register(self.definition)
        return false
    }

    deinit {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func register(_ definition: HotKeyDefinition) -> Bool {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            definition.keyCode,
            definition.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        return status == noErr
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

final class ShortcutRecorderView: NSView {
    private let statusLabel = NSTextField(labelWithString: "")
    private let onSave: (HotKeyDefinition) -> Void
    private let onCancel: () -> Void

    override var acceptsFirstResponder: Bool {
        true
    }

    init(currentHotKey: HotKeyDefinition, onSave: @escaping (HotKeyDefinition) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
        setupView(currentHotKey: currentHotKey)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            onCancel()
            return
        }

        guard let hotKey = HotKeyDefinition.from(event: event) else {
            statusLabel.stringValue = "Use Command, Control, or Option with a key."
            return
        }

        onSave(hotKey)
    }

    private func setupView(currentHotKey: HotKeyDefinition) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "Set Shortcut")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 24, y: 130, width: 260, height: 24)
        addSubview(titleLabel)

        let descriptionLabel = NSTextField(wrappingLabelWithString: "Press the shortcut you want to use. Include Command, Control, or Option. Press Esc to cancel.")
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.frame = NSRect(x: 24, y: 84, width: 372, height: 42)
        addSubview(descriptionLabel)

        let currentLabel = NSTextField(labelWithString: "Current: \(currentHotKey.displayName)")
        currentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        currentLabel.frame = NSRect(x: 24, y: 56, width: 260, height: 18)
        addSubview(currentLabel)

        statusLabel.stringValue = "Waiting for shortcut..."
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 24, y: 24, width: 240, height: 18)
        addSubview(statusLabel)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 310, y: 18, width: 86, height: 30)
        addSubview(cancelButton)
    }

    @objc private func cancel() {
        onCancel()
    }
}

final class FirstRunHintView: NSView {
    private let onDismiss: () -> Void

    init(shortcutName: String, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 164))
        wantsLayer = true
        layer?.cornerRadius = 12

        let iconView = NSImageView(frame: NSRect(x: 18, y: 116, width: 28, height: 28))
        if let image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil) {
            image.isTemplate = true
            iconView.image = image
        }
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: "LightoffReading is ready")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.frame = NSRect(x: 56, y: 122, width: 238, height: 20)
        addSubview(titleLabel)

        let bodyLabel = NSTextField(wrappingLabelWithString: "Use the floating HUD to turn the light on, then open adjustments while the screen is dimmed.")
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.frame = NSRect(x: 18, y: 74, width: 284, height: 38)
        addSubview(bodyLabel)

        let shortcutLabel = NSTextField(labelWithString: "Shortcut: \(shortcutName)")
        shortcutLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        shortcutLabel.textColor = .labelColor
        shortcutLabel.frame = NSRect(x: 18, y: 46, width: 284, height: 18)
        addSubview(shortcutLabel)

        let button = NSButton(title: "Got it", target: self, action: #selector(dismiss))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 220, y: 14, width: 82, height: 28)
        addSubview(button)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func dismiss() {
        onDismiss()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var config = SettingsStore.load()
    private var hotKeyDefinition = SettingsStore.loadHotKey()
    private var hotKey: GlobalHotKey?
    private var overlayController: OverlayController?
    private var floatingHUDController: FloatingHUDController?
    private var compactHUDController: CompactHUDController?
    private var shortcutRecorderPanel: NSPanel?
    private var firstRunPopover: NSPopover?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?
    private var hudVisibilityItem: NSMenuItem?
    private var shortcutItem: NSMenuItem?
    private var isHUDHiddenByUser = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("LightoffReading is a persistent menu bar utility.")

        overlayController = OverlayController(config: config)
        setupStatusItem()

        floatingHUDController = FloatingHUDController(
            config: config,
            isLightOn: overlayController?.isEnabled ?? false,
            onToggleLight: { [weak self] in
                self?.toggleReadingLight()
            },
            onResetDefaults: { [weak self] in
                guard let self else {
                    return
                }

                self.config = SettingsStore.defaultConfig
                self.applyConfigChange()
            },
            onConfigChange: { [weak self] updatedConfig in
                self?.config = updatedConfig
                self?.applyConfigChange()
            },
            onReturnToCompact: { [weak self] edge, centerY in
                guard let self, !self.isHUDHiddenByUser else {
                    return
                }

                self.compactHUDController?.showHandle(at: edge, centerY: centerY, animated: true)
            }
        )

        compactHUDController = CompactHUDController(
            isLightOn: overlayController?.isEnabled ?? false,
            shape: config.shape,
            onToggleLight: { [weak self] in
                self?.toggleReadingLight()
            },
            onCycleShape: { [weak self] in
                guard let self else {
                    return
                }

                self.config.shape = self.config.shape.next
                self.applyConfigChange()
            },
            onOpenAdjustments: { [weak self] edge, centerY in
                guard let self, !self.isHUDHiddenByUser else {
                    return
                }

                self.floatingHUDController?.show(from: edge, centerY: centerY, animated: true)
            }
        )

        floatingHUDController?.show(animated: false)
        floatingHUDController?.scheduleReturnToCompact(after: 3.2)
        _ = registerHotKey(hotKeyDefinition)

        refreshMenuState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.showFirstRunMenuBarHintIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Lightoff Reading") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Light"
            }
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Lightoff Reading", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Enable Reading Light", action: #selector(toggleReadingLight), keyEquivalent: hotKeyDefinition.keyEquivalent)
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = hotKeyDefinition.menuModifierFlags
        self.toggleItem = toggleItem
        menu.addItem(toggleItem)

        let shortcutItem = NSMenuItem(title: "Shortcut: \(hotKeyDefinition.displayName)", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        self.shortcutItem = shortcutItem
        menu.addItem(shortcutItem)

        let hudVisibilityItem = NSMenuItem(title: "Hide Floating HUD", action: #selector(toggleFloatingHUD), keyEquivalent: "")
        hudVisibilityItem.target = self
        self.hudVisibilityItem = hudVisibilityItem
        menu.addItem(hudVisibilityItem)

        let setShortcutItem = NSMenuItem(title: "Set Shortcut...", action: #selector(showShortcutRecorder), keyEquivalent: "")
        setShortcutItem.target = self
        menu.addItem(setShortcutItem)

        let resetShortcutItem = NSMenuItem(title: "Reset Shortcut", action: #selector(resetShortcut), keyEquivalent: "")
        resetShortcutItem.target = self
        menu.addItem(resetShortcutItem)

        menu.addItem(.separator())

        let supportItem = NSMenuItem(title: "Support Project", action: #selector(openSupportPage), keyEquivalent: "")
        supportItem.target = self
        menu.addItem(supportItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func showFirstRunMenuBarHintIfNeeded() {
        guard !SettingsStore.hasShownMenuBarHint,
              firstRunPopover == nil,
              let button = statusItem?.button else {
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 164)

        let viewController = NSViewController()
        viewController.view = FirstRunHintView(shortcutName: hotKeyDefinition.displayName) { [weak self] in
            self?.firstRunPopover?.close()
            self?.firstRunPopover = nil
        }
        popover.contentViewController = viewController

        firstRunPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        SettingsStore.markMenuBarHintShown()
    }

    @objc private func toggleReadingLight() {
        guard let overlayController else {
            return
        }

        overlayController.setEnabled(!overlayController.isEnabled)
        floatingHUDController?.updateLightState(overlayController.isEnabled)
        compactHUDController?.updateLightState(overlayController.isEnabled)
        refreshMenuState()
    }

    @objc private func showShortcutRecorder() {
        if let shortcutRecorderPanel {
            shortcutRecorderPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        hotKey = nil
        refreshMenuState()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Set Shortcut"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = ShortcutRecorderView(
            currentHotKey: hotKeyDefinition,
            onSave: { [weak self, weak panel] definition in
                guard self?.saveShortcut(definition) == true else {
                    return
                }

                panel?.close()
            },
            onCancel: { [weak self, weak panel] in
                if let self {
                    _ = self.registerHotKey(self.hotKeyDefinition)
                    self.refreshMenuState()
                }
                panel?.close()
            }
        )

        shortcutRecorderPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === shortcutRecorderPanel else {
            return
        }

        shortcutRecorderPanel = nil

        if hotKey == nil {
            _ = registerHotKey(hotKeyDefinition)
            refreshMenuState()
        }
    }

    @objc private func resetShortcut() {
        saveShortcut(HotKeyDefinition.defaultValue)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleFloatingHUD() {
        if isHUDHiddenByUser {
            isHUDHiddenByUser = false
            compactHUDController?.showToolbar(animated: true)
        } else {
            isHUDHiddenByUser = true
            floatingHUDController?.hide()
            compactHUDController?.hide()
        }

        refreshMenuState()
    }

    @objc private func openSupportPage() {
        guard let url = URL(string: "https://github.com/sponsors/andrewLi1994") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func applyConfigChange() {
        SettingsStore.save(config)
        overlayController?.update(config: config)
        floatingHUDController?.update(config: config)
        compactHUDController?.updateShape(config.shape)
    }

    @discardableResult
    private func saveShortcut(_ definition: HotKeyDefinition) -> Bool {
        guard registerHotKey(definition) else {
            _ = registerHotKey(hotKeyDefinition)
            refreshMenuState()
            showShortcutError(definition)
            return false
        }

        hotKeyDefinition = definition
        SettingsStore.saveHotKey(definition)
        refreshMenuState()
        return true
    }

    private func registerHotKey(_ definition: HotKeyDefinition) -> Bool {
        if let hotKey {
            return hotKey.update(definition: definition)
        }

        guard let hotKey = GlobalHotKey(definition: definition, action: { [weak self] in
            if Thread.isMainThread {
                self?.toggleReadingLight()
            } else {
                DispatchQueue.main.async {
                    self?.toggleReadingLight()
                }
            }
        }) else {
            return false
        }

        self.hotKey = hotKey
        return true
    }

    private func showShortcutError(_ definition: HotKeyDefinition) {
        let alert = NSAlert()
        alert.messageText = "Shortcut Unavailable"
        alert.informativeText = "\(definition.displayName) could not be registered. It may already be used by macOS or another app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func refreshMenuState() {
        if let overlayController {
            toggleItem?.title = overlayController.isEnabled ? "Disable Reading Light" : "Enable Reading Light"
        }

        toggleItem?.keyEquivalent = hotKeyDefinition.keyEquivalent
        toggleItem?.keyEquivalentModifierMask = hotKeyDefinition.menuModifierFlags

        if hotKey == nil {
            shortcutItem?.title = "Shortcut unavailable: \(hotKeyDefinition.displayName)"
        } else {
            shortcutItem?.title = "Shortcut: \(hotKeyDefinition.displayName)"
        }

        hudVisibilityItem?.title = isHUDHiddenByUser ? "Show Floating HUD" : "Hide Floating HUD"
    }
}
