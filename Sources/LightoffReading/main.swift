import AppKit
import Carbon.HIToolbox

enum SpotlightShape: String, CaseIterable {
    case ellipse
    case rectangle

    var displayName: String {
        switch self {
        case .ellipse:
            return "Ellipse"
        case .rectangle:
            return "Rectangle"
        }
    }
}

struct SpotlightConfig: Equatable {
    var shape: SpotlightShape
    var width: CGFloat
    var height: CGFloat
    var feather: CGFloat
    var opacity: CGFloat
    var cursorXOffset: CGFloat
    var cursorYOffset: CGFloat
}

struct HotKeyDefinition: Equatable {
    static let defaultValue = HotKeyDefinition(
        keyCode: UInt32(kVK_ANSI_L),
        carbonModifiers: UInt32(shiftKey | controlKey | cmdKey),
        displayKey: "L"
    )

    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayKey: String

    var displayName: String {
        let parts = modifierNames
        return (parts + [displayKey.uppercased()]).joined(separator: "-")
    }

    var keyEquivalent: String {
        if displayKey.count == 1 {
            return displayKey.lowercased()
        }

        return ""
    }

    var menuModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }

        return flags
    }

    private var modifierNames: [String] {
        var names: [String] = []

        if carbonModifiers & UInt32(shiftKey) != 0 {
            names.append("Shift")
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            names.append("Control")
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            names.append("Option")
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            names.append("Command")
        }

        return names
    }

    static func from(event: NSEvent) -> HotKeyDefinition? {
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])

        guard !modifiers.intersection([.control, .option, .command]).isEmpty else {
            return nil
        }

        let displayKey = displayKey(for: event)
        guard !displayKey.isEmpty else {
            return nil
        }

        return HotKeyDefinition(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonModifiers(from: modifiers),
            displayKey: displayKey
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if flags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if flags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if flags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }

        return carbonModifiers
    }

    private static func displayKey(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Space:
            return "Space"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Forward Delete"
        case kVK_LeftArrow:
            return "Left Arrow"
        case kVK_RightArrow:
            return "Right Arrow"
        case kVK_UpArrow:
            return "Up Arrow"
        case kVK_DownArrow:
            return "Down Arrow"
        case kVK_Home:
            return "Home"
        case kVK_End:
            return "End"
        case kVK_PageUp:
            return "Page Up"
        case kVK_PageDown:
            return "Page Down"
        case kVK_Escape:
            return ""
        default:
            return event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? ""
        }
    }
}

enum SettingsStore {
    private static let shapeKey = "spotlight.shape"
    private static let radiusKey = "spotlight.radius"
    private static let widthKey = "spotlight.width"
    private static let heightKey = "spotlight.height"
    private static let featherKey = "spotlight.feather"
    private static let opacityKey = "spotlight.opacity"
    private static let cursorXOffsetKey = "spotlight.cursorXOffset"
    private static let cursorYOffsetKey = "spotlight.cursorYOffset"
    private static let hotKeyCodeKey = "hotkey.keyCode"
    private static let hotKeyModifiersKey = "hotkey.modifiers"
    private static let hotKeyDisplayKey = "hotkey.displayKey"
    private static let menuBarHintShownKey = "onboarding.menuBarHintShown"

    static func load() -> SpotlightConfig {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            shapeKey: SpotlightShape.ellipse.rawValue,
            radiusKey: 120.0,
            widthKey: 360.0,
            heightKey: 260.0,
            featherKey: 48.0,
            opacityKey: 0.72,
            cursorXOffsetKey: -40.0,
            cursorYOffsetKey: 90.0
        ])
        let migratedSize = defaults.double(forKey: radiusKey) * 2
        let width = defaults.object(forKey: widthKey) == nil ? migratedSize : defaults.double(forKey: widthKey)
        let height = defaults.object(forKey: heightKey) == nil ? migratedSize : defaults.double(forKey: heightKey)

        return SpotlightConfig(
            shape: SpotlightShape(rawValue: defaults.string(forKey: shapeKey) ?? "") ?? .ellipse,
            width: CGFloat(width),
            height: CGFloat(height),
            feather: CGFloat(defaults.double(forKey: featherKey)),
            opacity: CGFloat(defaults.double(forKey: opacityKey)),
            cursorXOffset: CGFloat(defaults.double(forKey: cursorXOffsetKey)),
            cursorYOffset: CGFloat(defaults.double(forKey: cursorYOffsetKey))
        )
    }

    static func save(_ config: SpotlightConfig) {
        let defaults = UserDefaults.standard
        defaults.set(config.shape.rawValue, forKey: shapeKey)
        defaults.set(Double(config.width), forKey: widthKey)
        defaults.set(Double(config.height), forKey: heightKey)
        defaults.set(Double(config.feather), forKey: featherKey)
        defaults.set(Double(config.opacity), forKey: opacityKey)
        defaults.set(Double(config.cursorXOffset), forKey: cursorXOffsetKey)
        defaults.set(Double(config.cursorYOffset), forKey: cursorYOffsetKey)
    }

    static func loadHotKey() -> HotKeyDefinition {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            hotKeyCodeKey: Int(HotKeyDefinition.defaultValue.keyCode),
            hotKeyModifiersKey: Int(HotKeyDefinition.defaultValue.carbonModifiers),
            hotKeyDisplayKey: HotKeyDefinition.defaultValue.displayKey
        ])

        return HotKeyDefinition(
            keyCode: UInt32(defaults.integer(forKey: hotKeyCodeKey)),
            carbonModifiers: UInt32(defaults.integer(forKey: hotKeyModifiersKey)),
            displayKey: defaults.string(forKey: hotKeyDisplayKey) ?? HotKeyDefinition.defaultValue.displayKey
        )
    }

    static func saveHotKey(_ hotKey: HotKeyDefinition) {
        let defaults = UserDefaults.standard
        defaults.set(Int(hotKey.keyCode), forKey: hotKeyCodeKey)
        defaults.set(Int(hotKey.carbonModifiers), forKey: hotKeyModifiersKey)
        defaults.set(hotKey.displayKey, forKey: hotKeyDisplayKey)
    }

    static var hasShownMenuBarHint: Bool {
        UserDefaults.standard.bool(forKey: menuBarHintShownKey)
    }

    static func markMenuBarHintShown() {
        UserDefaults.standard.set(true, forKey: menuBarHintShownKey)
    }
}

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

final class SpotlightOverlayView: NSView {
    var config: SpotlightConfig {
        didSet {
            needsDisplay = true
        }
    }

    private var effectiveOpacity: CGFloat = 0
    private var effectiveSpotlightWidth: CGFloat = 0
    private var effectiveSpotlightHeight: CGFloat = 0
    private var effectiveFeather: CGFloat = 0
    private var spotlightCenter: NSPoint?

    var hasSpotlight: Bool {
        spotlightCenter != nil
    }

    override var isOpaque: Bool {
        false
    }

    init(config: SpotlightConfig) {
        self.config = config
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyRenderState(
        opacity: CGFloat,
        spotlightCenter: NSPoint?,
        width: CGFloat,
        height: CGFloat,
        feather: CGFloat
    ) {
        let clampedOpacity = opacity.clamped(to: 0...1)
        let clampedWidth = max(1, width)
        let clampedHeight = max(1, height)
        let clampedFeather = max(0, feather)
        let centerChanged: Bool

        switch (self.spotlightCenter, spotlightCenter) {
        case let (current?, next?):
            centerChanged = current.distance(to: next) > 0.5
        case (nil, nil):
            centerChanged = false
        default:
            centerChanged = true
        }

        let shouldRedraw = abs(effectiveOpacity - clampedOpacity) > 0.001
            || abs(effectiveSpotlightWidth - clampedWidth) > 0.5
            || abs(effectiveSpotlightHeight - clampedHeight) > 0.5
            || abs(effectiveFeather - clampedFeather) > 0.5
            || centerChanged

        effectiveOpacity = clampedOpacity
        effectiveSpotlightWidth = clampedWidth
        effectiveSpotlightHeight = clampedHeight
        effectiveFeather = clampedFeather
        self.spotlightCenter = spotlightCenter

        if shouldRedraw {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        guard effectiveOpacity > 0.001 else {
            return
        }

        context.setFillColor(NSColor.black.withAlphaComponent(effectiveOpacity).cgColor)
        context.fill(bounds)

        guard let spotlightCenter else {
            return
        }

        context.saveGState()
        context.setBlendMode(.destinationOut)

        switch config.shape {
        case .ellipse:
            drawEllipse(in: context, center: spotlightCenter)
        case .rectangle:
            drawSoftRect(in: context, rect: rect(centeredAt: spotlightCenter, width: effectiveSpotlightWidth, height: effectiveSpotlightHeight))
        }

        context.restoreGState()
    }

    private func drawEllipse(in context: CGContext, center: NSPoint) {
        let baseRadius = max(1, min(effectiveSpotlightWidth, effectiveSpotlightHeight) / 2)
        let scaleX = max(0.01, effectiveSpotlightWidth / (baseRadius * 2))
        let scaleY = max(0.01, effectiveSpotlightHeight / (baseRadius * 2))
        let feather = cappedFeather(forShortDimension: min(effectiveSpotlightWidth, effectiveSpotlightHeight))
        let gradientRadius = max(1, baseRadius + feather)
        let solidStop = max(0.01, min(0.98, baseRadius / gradientRadius))
        let colors = [
            NSColor.white.withAlphaComponent(1.0).cgColor,
            NSColor.white.withAlphaComponent(1.0).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, solidStop, 1.0]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else {
            return
        }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: scaleX, y: scaleY)
        context.drawRadialGradient(
            gradient,
            startCenter: .zero,
            startRadius: 0,
            endCenter: .zero,
            endRadius: gradientRadius,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private func drawSoftRect(in context: CGContext, rect: NSRect) {
        let feather = cappedFeather(forShortDimension: min(rect.width, rect.height))

        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)

        guard feather > 0.5 else {
            return
        }

        drawRectOuterFeather(in: context, rect: rect, feather: feather)
    }

    private func drawRectOuterFeather(in context: CGContext, rect: NSRect, feather: CGFloat) {
        let maxSteps = 72
        let steps = max(8, min(maxSteps, Int(feather.rounded(.up))))
        let stepWidth = feather / CGFloat(steps)

        context.saveGState()
        context.setLineJoin(.miter)

        for index in 0..<steps {
            let progress = CGFloat(index) / CGFloat(max(1, steps - 1))
            let distance = CGFloat(index) * stepWidth + stepWidth / 2
            let alpha = pow(1 - progress, 1.8)
            let strokeRect = rect.insetBy(dx: -distance, dy: -distance)

            context.setStrokeColor(NSColor.white.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(stepWidth)
            context.stroke(strokeRect)
        }

        context.restoreGState()
    }

    private func cappedFeather(forShortDimension shortDimension: CGFloat) -> CGFloat {
        min(effectiveFeather, max(1, shortDimension * 0.42))
    }

    private func rect(centeredAt center: NSPoint, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}

final class SpotlightOverlayWindow: NSWindow {
    private let overlayView: SpotlightOverlayView
    private(set) var displayID: CGDirectDisplayID

    var hasSpotlight: Bool {
        overlayView.hasSpotlight
    }

    var screenCoveringSize: CGSize {
        CGSize(width: frame.width * 1.6, height: frame.height * 1.6)
    }

    init(screen: NSScreen, config: SpotlightConfig) {
        self.overlayView = SpotlightOverlayView(config: config)
        self.displayID = screen.displayID

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = overlayView
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isOpaque = false
        isReleasedWhenClosed = false
        level = .screenSaver
    }

    func update(screen: NSScreen) {
        displayID = screen.displayID
        setFrame(screen.frame, display: true)
    }

    func update(config: SpotlightConfig) {
        overlayView.config = config
    }

    func applyRenderState(
        opacity: CGFloat,
        globalSpotlightPoint: NSPoint?,
        width: CGFloat,
        height: CGFloat,
        feather: CGFloat
    ) {
        let localPoint: NSPoint?

        if let globalSpotlightPoint {
            let windowPoint = convertPoint(fromScreen: globalSpotlightPoint)
            localPoint = overlayView.convert(windowPoint, from: nil)
        } else {
            localPoint = nil
        }

        overlayView.applyRenderState(
            opacity: opacity,
            spotlightCenter: localPoint,
            width: width,
            height: height,
            feather: feather
        )
    }

    func clearSpotlight() {
        overlayView.applyRenderState(
            opacity: 0,
            spotlightCenter: nil,
            width: overlayView.config.width,
            height: overlayView.config.height,
            feather: overlayView.config.feather
        )
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

        let titleLabel = NSTextField(labelWithString: "LightoffReading is running here")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.frame = NSRect(x: 56, y: 122, width: 238, height: 20)
        addSubview(titleLabel)

        let bodyLabel = NSTextField(wrappingLabelWithString: "Use this menu bar icon to adjust shape, width, height, soft edge, darkness, and shortcut.")
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

final class OverlayController {
    private enum OverlayState {
        case off
        case animatingOn
        case on
        case animatingOff
    }

    private struct OverlayAnimation {
        let fromProgress: CGFloat
        let toProgress: CGFloat
        let startTime: TimeInterval
        let duration: TimeInterval
    }

    private static let enableDuration: TimeInterval = 0.65
    private static let disableDuration: TimeInterval = 0.75

    private var config: SpotlightConfig
    private var windowsByDisplayID: [CGDirectDisplayID: SpotlightOverlayWindow] = [:]
    private var lastMouseLocation: NSPoint?
    private var pollTimer: Timer?
    private var state: OverlayState = .off
    private var visualProgress: CGFloat = 0
    private var animation: OverlayAnimation?

    var isEnabled: Bool {
        state == .animatingOn || state == .on
    }

    init(config: SpotlightConfig) {
        self.config = config
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopTimer()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled == isEnabled {
            return
        }

        if enabled {
            syncWindows()
            windowsByDisplayID.values.forEach { $0.orderFrontRegardless() }
            startTimerIfNeeded()
            startAnimation(to: 1, baseDuration: Self.enableDuration)
        } else {
            syncWindows()
            windowsByDisplayID.values.forEach { $0.orderFrontRegardless() }
            startTimerIfNeeded()
            startAnimation(to: 0, baseDuration: Self.disableDuration)
        }
    }

    func update(config: SpotlightConfig) {
        self.config = config
        windowsByDisplayID.values.forEach { $0.update(config: config) }

        if state != .off {
            tick(force: true)
        }
    }

    @objc private func screenParametersDidChange() {
        syncWindows()

        if state != .off {
            windowsByDisplayID.values.forEach { $0.orderFrontRegardless() }
            tick(force: true)
        }
    }

    private func startTimerIfNeeded() {
        guard pollTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick(force: false)
        }

        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func syncWindows() {
        let screens = NSScreen.screens
        let activeIDs = Set(screens.map(\.displayID))

        for displayID in windowsByDisplayID.keys.filter({ !activeIDs.contains($0) }) {
            guard let window = windowsByDisplayID[displayID] else {
                continue
            }

            window.orderOut(nil)
            windowsByDisplayID.removeValue(forKey: displayID)
        }

        for screen in screens {
            let displayID = screen.displayID

            if let window = windowsByDisplayID[displayID] {
                window.update(screen: screen)
                window.update(config: config)
            } else {
                windowsByDisplayID[displayID] = SpotlightOverlayWindow(screen: screen, config: config)
            }
        }
    }

    private func startAnimation(to targetProgress: CGFloat, baseDuration: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        _ = advanceAnimation(now: now)

        let distance = abs(targetProgress - visualProgress)
        guard distance > 0.001 else {
            completeAnimation(to: targetProgress)
            tick(force: true)
            return
        }

        state = targetProgress > visualProgress ? .animatingOn : .animatingOff
        animation = OverlayAnimation(
            fromProgress: visualProgress,
            toProgress: targetProgress,
            startTime: now,
            duration: max(0.12, baseDuration * TimeInterval(distance))
        )
        tick(force: true)
    }

    private func tick(force: Bool) {
        let animationChanged = advanceAnimation(now: ProcessInfo.processInfo.systemUptime)

        if state == .off {
            return
        }

        updateRenderState(force: force || animationChanged)
    }

    private func advanceAnimation(now: TimeInterval) -> Bool {
        guard let animation else {
            return false
        }

        let rawProgress = ((now - animation.startTime) / animation.duration).clamped(to: 0...1)
        let easedProgress = easeInOutCubic(CGFloat(rawProgress))
        visualProgress = animation.fromProgress + (animation.toProgress - animation.fromProgress) * easedProgress

        if rawProgress >= 1 {
            completeAnimation(to: animation.toProgress)
        }

        return true
    }

    private func completeAnimation(to targetProgress: CGFloat) {
        visualProgress = targetProgress.clamped(to: 0...1)
        animation = nil

        if visualProgress >= 0.999 {
            state = .on
        } else {
            state = .off
            finishOff()
        }
    }

    private func finishOff() {
        stopTimer()
        lastMouseLocation = nil
        windowsByDisplayID.values.forEach {
            $0.applyRenderState(
                opacity: 0,
                globalSpotlightPoint: nil,
                width: config.width,
                height: config.height,
                feather: config.feather
            )
            $0.orderOut(nil)
        }
    }

    private func updateRenderState(force: Bool) {
        let mouseLocation = NSEvent.mouseLocation

        if !force, let lastMouseLocation, lastMouseLocation.distance(to: mouseLocation) < 0.5 {
            return
        }

        lastMouseLocation = mouseLocation

        guard let activeScreen = screen(containing: mouseLocation) ?? NSScreen.main else {
            return
        }

        let activeDisplayID = activeScreen.displayID
        let spotlightPoint = clampedSpotlightPoint(for: mouseLocation, on: activeScreen)
        let opacity = config.opacity * visualProgress

        for (displayID, window) in windowsByDisplayID {
            if displayID == activeDisplayID {
                let coverSize = window.screenCoveringSize
                let expandedFeather = max(config.feather, min(coverSize.width, coverSize.height) * 0.08)
                let width = coverSize.width + (config.width - coverSize.width) * visualProgress
                let height = coverSize.height + (config.height - coverSize.height) * visualProgress
                let feather = expandedFeather + (config.feather - expandedFeather) * visualProgress

                window.applyRenderState(
                    opacity: opacity,
                    globalSpotlightPoint: spotlightPoint,
                    width: width,
                    height: height,
                    feather: feather
                )
            } else {
                window.applyRenderState(
                    opacity: opacity,
                    globalSpotlightPoint: nil,
                    width: config.width,
                    height: config.height,
                    feather: config.feather
                )
            }
        }
    }

    private func easeInOutCubic(_ progress: CGFloat) -> CGFloat {
        if progress < 0.5 {
            return 4 * progress * progress * progress
        }

        let shifted = -2 * progress + 2
        return 1 - (shifted * shifted * shifted) / 2
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func clampedSpotlightPoint(for mouseLocation: NSPoint, on screen: NSScreen) -> NSPoint {
        let frame = screen.frame
        let proposed = NSPoint(
            x: mouseLocation.x + config.cursorXOffset,
            y: mouseLocation.y + config.cursorYOffset
        )

        return NSPoint(
            x: proposed.x.clamped(to: frame.minX...frame.maxX),
            y: proposed.y.clamped(to: frame.minY...frame.maxY)
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var config = SettingsStore.load()
    private var hotKeyDefinition = SettingsStore.loadHotKey()
    private var hotKey: GlobalHotKey?
    private var overlayController: OverlayController?
    private var shortcutRecorderPanel: NSPanel?
    private var firstRunPopover: NSPopover?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?
    private var shortcutItem: NSMenuItem?
    private var shapeItems: [SpotlightShape: NSMenuItem] = [:]
    private var widthLabel: NSTextField?
    private var heightLabel: NSTextField?
    private var featherLabel: NSTextField?
    private var opacityLabel: NSTextField?
    private var horizontalOffsetLabel: NSTextField?
    private var offsetLabel: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("LightoffReading is a persistent menu bar utility.")

        overlayController = OverlayController(config: config)
        setupStatusItem()
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

        let setShortcutItem = NSMenuItem(title: "Set Shortcut...", action: #selector(showShortcutRecorder), keyEquivalent: "")
        setShortcutItem.target = self
        menu.addItem(setShortcutItem)

        let resetShortcutItem = NSMenuItem(title: "Reset Shortcut", action: #selector(resetShortcut), keyEquivalent: "")
        resetShortcutItem.target = self
        menu.addItem(resetShortcutItem)

        menu.addItem(.separator())
        menu.addItem(makeShapeMenuItem())
        menu.addItem(makeSliderItem(title: "Width", value: Double(config.width), range: 0...2000, label: &widthLabel, action: #selector(widthChanged(_:))))
        menu.addItem(makeSliderItem(title: "Height", value: Double(config.height), range: 0...2000, label: &heightLabel, action: #selector(heightChanged(_:))))
        menu.addItem(makeSliderItem(title: "Soft Edge", value: Double(config.feather), range: 0...240, label: &featherLabel, action: #selector(featherChanged(_:))))
        menu.addItem(makeSliderItem(title: "Darkness", value: Double(config.opacity), range: 0.35...0.90, label: &opacityLabel, action: #selector(opacityChanged(_:))))
        menu.addItem(makeSliderItem(title: "Left / Right", value: Double(config.cursorXOffset), range: -220...220, label: &horizontalOffsetLabel, action: #selector(horizontalOffsetChanged(_:))))
        menu.addItem(makeSliderItem(title: "Above Cursor", value: Double(config.cursorYOffset), range: 20...220, label: &offsetLabel, action: #selector(offsetChanged(_:))))

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

    private func makeShapeMenuItem() -> NSMenuItem {
        shapeItems.removeAll()

        let item = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for shape in [SpotlightShape.ellipse, .rectangle] {
            let shapeItem = NSMenuItem(title: shape.displayName, action: #selector(shapeChanged(_:)), keyEquivalent: "")
            shapeItem.target = self
            shapeItem.representedObject = shape.rawValue
            shapeItems[shape] = shapeItem
            submenu.addItem(shapeItem)
        }

        item.submenu = submenu
        return item
    }

    private func makeSliderItem(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        label: inout NSTextField?,
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 268, height: 52))

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.frame = NSRect(x: 14, y: 29, width: 142, height: 16)
        container.addSubview(titleLabel)

        let valueLabel = NSTextField(labelWithString: "")
        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.frame = NSRect(x: 154, y: 29, width: 96, height: 16)
        container.addSubview(valueLabel)
        label = valueLabel

        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: self, action: action)
        slider.isContinuous = true
        slider.frame = NSRect(x: 12, y: 6, width: 242, height: 20)
        container.addSubview(slider)

        item.view = container
        return item
    }

    @objc private func toggleReadingLight() {
        guard let overlayController else {
            return
        }

        overlayController.setEnabled(!overlayController.isEnabled)
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

    @objc private func widthChanged(_ sender: NSSlider) {
        config.width = CGFloat(sender.doubleValue.rounded())
        applyConfigChange()
    }

    @objc private func heightChanged(_ sender: NSSlider) {
        config.height = CGFloat(sender.doubleValue.rounded())
        applyConfigChange()
    }

    @objc private func shapeChanged(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let shape = SpotlightShape(rawValue: rawValue) else {
            return
        }

        config.shape = shape
        applyConfigChange()
    }

    @objc private func featherChanged(_ sender: NSSlider) {
        config.feather = CGFloat(sender.doubleValue.rounded())
        applyConfigChange()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        config.opacity = CGFloat(sender.doubleValue)
        applyConfigChange()
    }

    @objc private func horizontalOffsetChanged(_ sender: NSSlider) {
        config.cursorXOffset = CGFloat(sender.doubleValue.rounded())
        applyConfigChange()
    }

    @objc private func offsetChanged(_ sender: NSSlider) {
        config.cursorYOffset = CGFloat(sender.doubleValue.rounded())
        applyConfigChange()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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
        refreshShapeItems()
        refreshSliderLabels()
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
            DispatchQueue.main.async {
                self?.toggleReadingLight()
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

        refreshShapeItems()
        refreshSliderLabels()
    }

    private func refreshShapeItems() {
        for (shape, item) in shapeItems {
            item.state = shape == config.shape ? .on : .off
        }
    }

    private func refreshSliderLabels() {
        widthLabel?.stringValue = "\(Int(config.width)) px"
        heightLabel?.stringValue = "\(Int(config.height)) px"
        featherLabel?.stringValue = "\(Int(config.feather)) px"
        opacityLabel?.stringValue = "\(Int((config.opacity * 100).rounded()))%"
        horizontalOffsetLabel?.stringValue = "\(Int(config.cursorXOffset)) px"
        offsetLabel?.stringValue = "\(Int(config.cursorYOffset)) px"
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }

        return number.uint32Value
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension NSPoint {
    func distance(to point: NSPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
