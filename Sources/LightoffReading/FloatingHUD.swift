import AppKit

final class FloatingHUDWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class HUDSliderRow: NSView {
    let slider: NSSlider
    private let valueLabel: NSTextField
    private let formatter: (Double) -> String
    private let onChange: (Double) -> Void

    private static let iconColumnWidth: CGFloat = 24
    private static let iconSliderGap: CGFloat = 6

    init(
        title: String,
        symbolName: String,
        value: Double,
        range: ClosedRange<Double>,
        formatter: @escaping (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) {
        self.slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil, action: nil)
        self.valueLabel = NSTextField(labelWithString: formatter(value))
        self.formatter = formatter
        self.onChange = onChange

        let contentLeft = Self.iconColumnWidth + Self.iconSliderGap

        super.init(frame: NSRect(x: 0, y: 0, width: 268, height: 48))

        let iconView = NSImageView(frame: NSRect(x: 0, y: 8, width: 18, height: 18))
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title) {
            image.isTemplate = true
            iconView.image = image
        }
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageAlignment = .alignCenter
        addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: contentLeft, y: 29, width: 132 - contentLeft, height: 16)
        addSubview(titleLabel)

        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.frame = NSRect(x: 150, y: 29, width: 118, height: 16)
        addSubview(valueLabel)

        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        slider.frame = NSRect(x: contentLeft - 2, y: 6, width: 272 - contentLeft, height: 22)
        addSubview(slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Double) {
        slider.doubleValue = value
        valueLabel.stringValue = formatter(value)
    }

    func setLocked(_ locked: Bool) {
        slider.isEnabled = !locked
        if locked {
            valueLabel.stringValue = "Auto"
            valueLabel.textColor = .tertiaryLabelColor
        } else {
            valueLabel.stringValue = formatter(slider.doubleValue)
            valueLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func sliderChanged() {
        valueLabel.stringValue = formatter(slider.doubleValue)
        onChange(slider.doubleValue)
    }
}

private final class HoverIconButton: NSButton {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
        super.mouseExited(with: event)
    }
}

final class FloatingHUDView: NSVisualEffectView {
    private static let contentSize = NSSize(width: 308, height: 416)
    private static let cornerRadius: CGFloat = 18

    var onToggleLight: (() -> Void)?
    var onResetDefaults: (() -> Void)?
    var onConfigChange: ((SpotlightConfig) -> Void)?
    var onMouseEnteredHUD: (() -> Void)?
    var onMouseExitedHUD: (() -> Void)?
    var onActivity: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private var config: SpotlightConfig
    private var trackingArea: NSTrackingArea?
    private var dragStartLocation: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var topControlsView: NSVisualEffectView!
    private var topControlsDivider: NSBox!
    private var powerButton: HoverIconButton!
    private var resetButton: HoverIconButton!
    private var headerStackView: NSView!
    private var headerLabel: NSTextField!
    private var hoverHintLabel: NSTextField!
    private var shapeControl: NSSegmentedControl!
    private var widthRow: HUDSliderRow!
    private var heightRow: HUDSliderRow!
    private var featherRow: HUDSliderRow!
    private var opacityRow: HUDSliderRow!
    private var horizontalOffsetRow: HUDSliderRow!
    private var verticalOffsetRow: HUDSliderRow!
    private var isLightOn: Bool
    private let topControlY: CGFloat = 366
    private let sectionLabelX: CGFloat = 20

    static var panelContentSize: NSSize {
        contentSize
    }

    init(config: SpotlightConfig, isLightOn: Bool) {
        self.config = config
        self.isLightOn = isLightOn
        super.init(frame: NSRect(origin: .zero, size: Self.contentSize))

        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true

        setupControls()
        updateLightState(isLightOn)
        update(config: config)
        updateRoundedMask()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateRoundedMask()
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnteredHUD?()
    }

    override func mouseExited(with event: NSEvent) {
        setHoverHint(nil)
        onMouseExitedHUD?()
    }

    override func mouseMoved(with event: NSEvent) {
        onActivity?()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartLocation,
              let dragStartOrigin else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        onDragMoved?(NSPoint(
            x: dragStartOrigin.x + currentLocation.x - dragStartLocation.x,
            y: dragStartOrigin.y + currentLocation.y - dragStartLocation.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        dragStartOrigin = nil
        onDragEnded?()
    }

    func update(config: SpotlightConfig) {
        self.config = config

        let segmentIndex: Int
        switch config.shape {
        case .ellipse: segmentIndex = 0
        case .rectangle: segmentIndex = 1
        case .horizontalStrip: segmentIndex = 2
        case .verticalStrip: segmentIndex = 3
        }
        shapeControl.selectedSegment = segmentIndex

        widthRow.setValue(Double(config.width))
        heightRow.setValue(Double(config.height))
        widthRow.setLocked(config.shape == .horizontalStrip)
        heightRow.setLocked(config.shape == .verticalStrip)

        featherRow.setValue(Double(config.feather))
        opacityRow.setValue(Double(config.opacity))
        horizontalOffsetRow.setValue(Double(config.cursorXOffset))
        verticalOffsetRow.setValue(Double(config.cursorYOffset))
    }

    func updateLightState(_ isLightOn: Bool) {
        self.isLightOn = isLightOn

        if let image = NSImage(
            systemSymbolName: isLightOn ? "power.circle.fill" : "power",
            accessibilityDescription: nil
        ) {
            image.isTemplate = true
            powerButton.image = image
        }

        powerButton.contentTintColor = isLightOn ? .white : .secondaryLabelColor
        powerButton.toolTip = isLightOn ? "Turn Off Reading Light" : "Turn On Reading Light"
        layer?.borderWidth = isLightOn ? 1.5 : 1
        layer?.borderColor = NSColor.white.withAlphaComponent(isLightOn ? 0.35 : 0.18).cgColor
    }

    private func updateRoundedMask() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let mask = NSImage(size: bounds.size)
        mask.lockFocus()
        NSColor.black.setFill()
        let radius = min(Self.cornerRadius, min(bounds.width, bounds.height) / 2)
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: bounds.size),
            xRadius: radius,
            yRadius: radius
        ).fill()
        mask.unlockFocus()
        maskImage = mask
    }

    private func setupControls() {
        topControlsView = NSVisualEffectView(frame: NSRect(x: 20, y: 366, width: 92, height: 36))
        topControlsView.material = .sidebar
        topControlsView.blendingMode = .withinWindow
        topControlsView.state = .active
        topControlsView.wantsLayer = true
        topControlsView.layer?.cornerRadius = 12
        topControlsView.layer?.masksToBounds = true
        topControlsView.layer?.borderWidth = 1
        topControlsView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        addSubview(topControlsView)

        powerButton = makeIconButton(symbol: "power", action: #selector(toggleLight))
        powerButton.frame = NSRect(x: 0, y: 0, width: 46, height: 36)
        powerButton.toolTip = "Toggle Reading Light"
        powerButton.onHoverChanged = { [weak self] isHovered in
            self?.setHoverHint(isHovered ? "Toggle Reading Light" : nil)
        }
        topControlsView.addSubview(powerButton)

        topControlsDivider = NSBox(frame: NSRect(x: 45, y: 8, width: 1, height: 20))
        topControlsDivider.boxType = .separator
        topControlsView.addSubview(topControlsDivider)

        resetButton = makeIconButton(symbol: "arrow.counterclockwise", action: #selector(resetDefaults))
        resetButton.frame = NSRect(x: 46, y: 0, width: 46, height: 36)
        resetButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        resetButton.contentTintColor = NSColor.secondaryLabelColor.withAlphaComponent(0.68)
        resetButton.toolTip = "Reset to Default"
        resetButton.onHoverChanged = { [weak self] isHovered in
            self?.setHoverHint(isHovered ? "Reset to Default" : nil)
        }
        topControlsView.addSubview(resetButton)

        headerStackView = NSView(frame: NSRect(x: 126, y: 366, width: 162, height: 36))
        addSubview(headerStackView)

        headerLabel = NSTextField(labelWithString: "Live Adjust")
        headerLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.frame = NSRect(x: 0, y: 18, width: 162, height: 14)
        headerStackView.addSubview(headerLabel)

        hoverHintLabel = NSTextField(labelWithString: "")
        hoverHintLabel.font = .systemFont(ofSize: 10, weight: .medium)
        hoverHintLabel.textColor = .tertiaryLabelColor
        hoverHintLabel.frame = NSRect(x: 0, y: 2, width: 162, height: 12)
        hoverHintLabel.isHidden = true
        headerStackView.addSubview(hoverHintLabel)

        let divider = NSBox(frame: NSRect(x: 20, y: 352, width: 268, height: 1))
        divider.boxType = .separator
        addSubview(divider)

        let shapeLabel = NSTextField(labelWithString: "Shape")
        shapeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        shapeLabel.textColor = .secondaryLabelColor
        shapeLabel.frame = NSRect(x: sectionLabelX, y: 330, width: 120, height: 14)
        addSubview(shapeLabel)

        shapeControl = NSSegmentedControl(labels: ["Ellipse", "Rect", "Full W", "Full H"], trackingMode: .selectOne, target: self, action: #selector(shapeChanged))
        shapeControl.frame = NSRect(x: 20, y: 292, width: 268, height: 34)
        addSubview(shapeControl)

        let parametersLabel = NSTextField(labelWithString: "Parameters")
        parametersLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        parametersLabel.textColor = .secondaryLabelColor
        parametersLabel.frame = NSRect(x: sectionLabelX, y: 270, width: 120, height: 14)
        addSubview(parametersLabel)

        widthRow = makeRow(title: "Width", symbolName: "arrow.left.and.right", value: Double(config.width), range: 0...3000, formatter: pixelFormatter) { [weak self] value in
            self?.config.width = CGFloat(value.rounded())
            self?.emitConfigChange()
        }
        widthRow.frame.origin = NSPoint(x: 20, y: 220)
        addSubview(widthRow)

        heightRow = makeRow(title: "Height", symbolName: "arrow.up.and.down", value: Double(config.height), range: 0...3000, formatter: pixelFormatter) { [weak self] value in
            self?.config.height = CGFloat(value.rounded())
            self?.emitConfigChange()
        }
        heightRow.frame.origin = NSPoint(x: 20, y: 180)
        addSubview(heightRow)

        featherRow = makeRow(title: "Soft Edge", symbolName: "circle.dashed", value: Double(config.feather), range: 0...240, formatter: pixelFormatter) { [weak self] value in
            self?.config.feather = CGFloat(value.rounded())
            self?.emitConfigChange()
        }
        featherRow.frame.origin = NSPoint(x: 20, y: 140)
        addSubview(featherRow)

        opacityRow = makeRow(title: "Darkness", symbolName: "circle.lefthalf.filled", value: Double(config.opacity), range: 0...1, formatter: percentFormatter) { [weak self] value in
            self?.config.opacity = CGFloat(value)
            self?.emitConfigChange()
        }
        opacityRow.frame.origin = NSPoint(x: 20, y: 100)
        addSubview(opacityRow)

        horizontalOffsetRow = makeRow(title: "Left / Right", symbolName: "arrow.left.arrow.right", value: Double(config.cursorXOffset), range: -500...500, formatter: pixelFormatter) { [weak self] value in
            self?.config.cursorXOffset = CGFloat(value.rounded())
            self?.emitConfigChange()
        }
        horizontalOffsetRow.frame.origin = NSPoint(x: 20, y: 60)
        addSubview(horizontalOffsetRow)

        verticalOffsetRow = makeRow(title: "Up / Down", symbolName: "arrow.up.arrow.down", value: Double(config.cursorYOffset), range: -500...500, formatter: pixelFormatter) { [weak self] value in
            self?.config.cursorYOffset = CGFloat(value.rounded())
            self?.emitConfigChange()
        }
        verticalOffsetRow.frame.origin = NSPoint(x: 20, y: 20)
        addSubview(verticalOffsetRow)
    }

    private func makeIconButton(symbol: String, action: Selector) -> HoverIconButton {
        let button = HoverIconButton(frame: .zero)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = action
        button.setButtonType(.momentaryPushIn)

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        }

        return button
    }

    private func setHoverHint(_ text: String?) {
        guard let text, !text.isEmpty else {
            hoverHintLabel.stringValue = ""
            hoverHintLabel.isHidden = true
            return
        }

        hoverHintLabel.stringValue = text
        hoverHintLabel.isHidden = false
    }

    private func makeRow(
        title: String,
        symbolName: String,
        value: Double,
        range: ClosedRange<Double>,
        formatter: @escaping (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) -> HUDSliderRow {
        HUDSliderRow(title: title, symbolName: symbolName, value: value, range: range, formatter: formatter, onChange: onChange)
    }

    private func pixelFormatter(_ value: Double) -> String {
        "\(Int(value.rounded())) px"
    }

    private func percentFormatter(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func emitConfigChange() {
        update(config: config)
        onConfigChange?(config)
        onActivity?()
    }

    @objc private func toggleLight() {
        onToggleLight?()
        onActivity?()
    }

    @objc private func resetDefaults() {
        onResetDefaults?()
        onActivity?()
    }

    @objc private func shapeChanged() {
        let shapes: [SpotlightShape] = [.ellipse, .rectangle, .horizontalStrip, .verticalStrip]
        config.shape = shapes[shapeControl.selectedSegment]
        emitConfigChange()
    }
}

final class FloatingHUDController {
    private static let revealDuration: TimeInterval = 0.22
    private static let collapseDuration: TimeInterval = 0.22
    private static let autoCollapseDelay: TimeInterval = 1.2
    private static let edgeInset: CGFloat = 14
    private static let revealOffset: CGFloat = 32
    private static let pointerMonitorInterval: TimeInterval = 1.0 / 12.0
    private static let pointerPadding: CGFloat = 6

    private let window: FloatingHUDWindow
    private let hudView: FloatingHUDView
    private let onReturnToCompact: (HUDEdge, CGFloat) -> Void
    private var retreatTimer: Timer?
    private var pointerMonitorTimer: Timer?
    private var isDragging = false

    init(
        config: SpotlightConfig,
        isLightOn: Bool,
        onToggleLight: @escaping () -> Void,
        onResetDefaults: @escaping () -> Void,
        onConfigChange: @escaping (SpotlightConfig) -> Void,
        onReturnToCompact: @escaping (HUDEdge, CGFloat) -> Void
    ) {
        let initialFrame = Self.defaultFrame(size: FloatingHUDView.panelContentSize)

        self.window = FloatingHUDWindow(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.hudView = FloatingHUDView(config: config, isLightOn: isLightOn)
        self.onReturnToCompact = onReturnToCompact

        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = hudView
        window.hasShadow = true
        window.isMovable = false
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        window.acceptsMouseMovedEvents = true

        hudView.onToggleLight = onToggleLight
        hudView.onResetDefaults = onResetDefaults
        hudView.onConfigChange = onConfigChange
        hudView.onMouseEnteredHUD = { [weak self] in
            self?.updatePointerPresenceState()
        }
        hudView.onMouseExitedHUD = { [weak self] in
            self?.updatePointerPresenceState()
        }
        hudView.onActivity = { [weak self] in
            self?.updatePointerPresenceState()
        }
        hudView.onDragBegan = { [weak self] in
            self?.beginDrag()
        }
        hudView.onDragMoved = { [weak self] origin in
            self?.move(to: origin)
        }
        hudView.onDragEnded = { [weak self] in
            self?.endDrag()
        }
    }

    func update(config: SpotlightConfig) {
        hudView.update(config: config)
    }

    func updateLightState(_ isLightOn: Bool) {
        hudView.updateLightState(isLightOn)
    }

    func show(from edge: HUDEdge? = nil, centerY: CGFloat? = nil, animated: Bool = true) {
        cancelScheduledReturn()
        startPointerMonitorIfNeeded()
        let finalEdge = edge ?? nearestHorizontalEdge(for: window.frame)
        let finalFrame = anchoredFrame(for: finalEdge, centerY: centerY ?? window.frame.midY)

        if !window.isVisible {
            let startFrame = shiftedFrame(forRevealFrom: finalEdge, targetFrame: finalFrame)
            window.setFrame(startFrame, display: false)
            window.alphaValue = animated ? 0 : 1
        }

        window.orderFrontRegardless()

        if animated {
            animate(to: finalFrame, duration: Self.revealDuration, timing: .easeOut, alpha: 1)
        } else {
            window.setFrame(finalFrame, display: true)
            window.alphaValue = 1
        }

        DispatchQueue.main.async { [weak self] in
            self?.updatePointerPresenceState()
        }
    }

    func hide() {
        cancelScheduledReturn()
        stopPointerMonitor()
        window.orderOut(nil)
    }

    func scheduleReturnToCompact(after delay: TimeInterval = FloatingHUDController.autoCollapseDelay) {
        armReturnToCompact(after: delay, resetExisting: true)
    }

    private func armReturnToCompact(
        after delay: TimeInterval = FloatingHUDController.autoCollapseDelay,
        resetExisting: Bool = false
    ) {
        if resetExisting {
            cancelScheduledReturn()
        }

        guard retreatTimer == nil else {
            return
        }

        guard window.isVisible, !isDragging else {
            return
        }

        retreatTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.returnToCompact(animated: true)
        }
    }

    func returnToCompact(animated: Bool) {
        cancelScheduledReturn()

        guard window.isVisible else {
            return
        }

        let edge = nearestHorizontalEdge(for: window.frame)
        let centerY = window.frame.midY

        let completeCollapse = { [weak self] in
            guard let self else {
                return
            }

            self.stopPointerMonitor()
            self.window.orderOut(nil)
            self.onReturnToCompact(edge, centerY)
        }

        guard animated else {
            completeCollapse()
            return
        }

        let targetFrame = shiftedFrame(forCollapseTo: edge, originFrame: window.frame)
        animate(
            to: targetFrame,
            duration: Self.collapseDuration,
            timing: .easeInEaseOut,
            alpha: 0,
            completion: completeCollapse
        )
    }

    private func beginDrag() {
        cancelScheduledReturn()
        isDragging = true
    }

    private func move(to origin: NSPoint) {
        var frame = window.frame
        frame.origin = origin
        window.setFrame(frame, display: true)
    }

    private func endDrag() {
        isDragging = false
        window.setFrame(clampedFrame(window.frame), display: true)
        updatePointerPresenceState()
    }

    private func cancelScheduledReturn() {
        retreatTimer?.invalidate()
        retreatTimer = nil
    }

    private func startPointerMonitorIfNeeded() {
        guard pointerMonitorTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: Self.pointerMonitorInterval, repeats: true) { [weak self] _ in
            self?.updatePointerPresenceState()
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerMonitorTimer = timer
    }

    private func stopPointerMonitor() {
        pointerMonitorTimer?.invalidate()
        pointerMonitorTimer = nil
    }

    private func updatePointerPresenceState() {
        guard window.isVisible, !isDragging else {
            return
        }

        let hoverFrame = window.frame.insetBy(dx: -Self.pointerPadding, dy: -Self.pointerPadding)

        if hoverFrame.contains(NSEvent.mouseLocation) {
            cancelScheduledReturn()
        } else {
            armReturnToCompact(after: Self.autoCollapseDelay, resetExisting: false)
        }
    }

    private func animate(
        to frame: NSRect,
        duration: TimeInterval,
        timing: CAMediaTimingFunctionName,
        alpha: CGFloat,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timing)
            window.animator().setFrame(frame, display: true)
            window.animator().alphaValue = alpha
        }, completionHandler: completion)
    }

    private func shiftedFrame(forRevealFrom edge: HUDEdge, targetFrame: NSRect) -> NSRect {
        var frame = targetFrame

        switch edge {
        case .left:
            frame.origin.x -= Self.revealOffset
        case .right:
            frame.origin.x += Self.revealOffset
        }

        return frame
    }

    private func shiftedFrame(forCollapseTo edge: HUDEdge, originFrame: NSRect) -> NSRect {
        var frame = originFrame

        switch edge {
        case .left:
            frame.origin.x -= Self.revealOffset * 0.6
        case .right:
            frame.origin.x += Self.revealOffset * 0.6
        }

        return frame
    }

    private func anchoredFrame(for edge: HUDEdge, centerY: CGFloat) -> NSRect {
        let size = FloatingHUDView.panelContentSize
        let visibleFrame = screen(for: window.frame).visibleFrame
        let y = (centerY - size.height / 2).clamped(to: visibleFrame.minY + Self.edgeInset...visibleFrame.maxY - size.height - Self.edgeInset)

        switch edge {
        case .left:
            return NSRect(
                x: visibleFrame.minX + Self.edgeInset,
                y: y,
                width: size.width,
                height: size.height
            )
        case .right:
            return NSRect(
                x: visibleFrame.maxX - size.width - Self.edgeInset,
                y: y,
                width: size.width,
                height: size.height
            )
        }
    }

    private func clampedFrame(_ frame: NSRect) -> NSRect {
        let visibleFrame = screen(for: frame).visibleFrame
        return NSRect(
            x: frame.origin.x.clamped(to: visibleFrame.minX...max(visibleFrame.minX, visibleFrame.maxX - frame.width)),
            y: frame.origin.y.clamped(to: visibleFrame.minY...max(visibleFrame.minY, visibleFrame.maxY - frame.height)),
            width: frame.width,
            height: frame.height
        )
    }

    private func nearestHorizontalEdge(for frame: NSRect) -> HUDEdge {
        let visibleFrame = screen(for: frame).visibleFrame

        if abs(frame.minX - visibleFrame.minX) < abs(visibleFrame.maxX - frame.maxX) {
            return .left
        }

        return .right
    }

    private func screen(for frame: NSRect) -> NSScreen {
        let intersectingScreens = NSScreen.screens.map { screen in
            (screen, frame.intersection(screen.frame).area)
        }

        if let bestMatch = intersectingScreens.max(by: { $0.1 < $1.1 }),
           bestMatch.1 > 0 {
            return bestMatch.0
        }

        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func defaultFrame(size: NSSize) -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visibleFrame.maxX - size.width - 26,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
