import AppKit

private enum CompactHUDMode {
    case handle
    case toolbar
}

private final class PillBackgroundView: NSVisualEffectView {
    var onMouseDownEvent: ((NSEvent) -> Void)?
    var onMouseDraggedEvent: ((NSEvent) -> Void)?
    var onMouseUpEvent: ((NSEvent) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateRoundedMask()
    }

    override func layout() {
        super.layout()
        updateRoundedMask()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDownEvent?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDraggedEvent?(event)
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUpEvent?(event)
    }

    private func updateRoundedMask() {
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2

        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let mask = NSImage(size: bounds.size)
        mask.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: bounds.size),
            xRadius: min(bounds.width, bounds.height) / 2,
            yRadius: min(bounds.width, bounds.height) / 2
        ).fill()
        mask.unlockFocus()
        maskImage = mask
    }
}

final class CompactHUDWindow: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class CompactHUDView: NSView {
    static let handleSize = NSSize(width: 20, height: 36)
    static let toolbarWindowSize = NSSize(width: 68, height: 132)

    var onToggleLight: (() -> Void)?
    var onOpenAdjustments: (() -> Void)?
    var onHandleHover: (() -> Void)?
    var onToolbarExit: (() -> Void)?
    var onToolbarEnter: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private let capsuleView = PillBackgroundView(frame: .zero)
    private let nubView = PillBackgroundView(frame: .zero)
    private let chevronView = NSImageView(frame: .zero)
    private let powerButton = NSButton(frame: .zero)
    private let adjustButton = NSButton(frame: .zero)

    private var trackingArea: NSTrackingArea?
    private var mode: CompactHUDMode = .handle
    private var edge: HUDEdge = .right
    private var isLightOn: Bool = false
    private var dragStartLocation: NSPoint?
    private var dragStartOrigin: NSPoint?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    init(isLightOn: Bool) {
        self.isLightOn = isLightOn
        super.init(frame: NSRect(origin: .zero, size: Self.handleSize))
        setupViews()
        updateLightState(isLightOn)
        setMode(.handle, edge: .right)
    }

    required init?(coder: NSCoder) {
        nil
    }

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
        switch mode {
        case .handle:
            onHandleHover?()
        case .toolbar:
            onToolbarEnter?()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if mode == .toolbar {
            onToolbarExit?()
        }
    }

    func updateLightState(_ isLightOn: Bool) {
        self.isLightOn = isLightOn
        let symbolName = isLightOn ? "power.circle.fill" : "power"

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            powerButton.image = image
        }

        powerButton.contentTintColor = isLightOn ? .white : .secondaryLabelColor
        powerButton.toolTip = isLightOn ? "Turn Off Reading Light" : "Turn On Reading Light"
    }

    fileprivate func setMode(_ mode: CompactHUDMode, edge: HUDEdge) {
        self.mode = mode
        self.edge = edge

        frame.size = mode == .handle ? Self.handleSize : Self.toolbarWindowSize
        layoutForCurrentState()
    }

    private func setupViews() {
        wantsLayer = true

        addSubview(capsuleView)
        addSubview(nubView)

        chevronView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        chevronView.contentTintColor = .secondaryLabelColor
        chevronView.imageAlignment = .alignCenter
        nubView.addSubview(chevronView)

        powerButton.isBordered = false
        powerButton.imagePosition = .imageOnly
        powerButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        powerButton.target = self
        powerButton.action = #selector(toggleLight)
        capsuleView.addSubview(powerButton)

        adjustButton.isBordered = false
        adjustButton.imagePosition = .imageOnly
        adjustButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 21, weight: .regular)
        adjustButton.contentTintColor = .secondaryLabelColor
        adjustButton.target = self
        adjustButton.action = #selector(openAdjustments)
        adjustButton.toolTip = "Adjust Reading Area"
        if let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil) {
            image.isTemplate = true
            adjustButton.image = image
        }
        capsuleView.addSubview(adjustButton)

        nubView.onMouseDownEvent = { [weak self] event in
            self?.beginDrag(with: event)
        }
        nubView.onMouseDraggedEvent = { [weak self] event in
            self?.continueDrag(with: event)
        }
        nubView.onMouseUpEvent = { [weak self] event in
            self?.endDrag(with: event)
        }

        capsuleView.onMouseDownEvent = { [weak self] event in
            self?.beginDrag(with: event)
        }
        capsuleView.onMouseDraggedEvent = { [weak self] event in
            self?.continueDrag(with: event)
        }
        capsuleView.onMouseUpEvent = { [weak self] event in
            self?.endDrag(with: event)
        }
    }

    private func layoutForCurrentState() {
        let handleBounds = NSRect(origin: .zero, size: Self.handleSize)

        if mode == .handle {
            capsuleView.isHidden = true
            nubView.frame = handleBounds
            chevronView.frame = NSRect(x: 3, y: 9, width: 14, height: 18)
            updateChevron()
            needsLayout = true
            return
        }

        capsuleView.isHidden = false

        let capsuleSize = NSSize(width: 56, height: 132)
        let nubSize = NSSize(width: 20, height: 48)
        let nubY = (Self.toolbarWindowSize.height - nubSize.height) / 2

        switch edge {
        case .left:
            nubView.frame = NSRect(x: 0, y: nubY, width: nubSize.width, height: nubSize.height)
            capsuleView.frame = NSRect(x: 12, y: 0, width: capsuleSize.width, height: capsuleSize.height)
        case .right:
            capsuleView.frame = NSRect(x: 0, y: 0, width: capsuleSize.width, height: capsuleSize.height)
            nubView.frame = NSRect(x: Self.toolbarWindowSize.width - nubSize.width, y: nubY, width: nubSize.width, height: nubSize.height)
        }

        powerButton.frame = NSRect(
            x: (capsuleView.bounds.width - 28) / 2,
            y: 72,
            width: 28,
            height: 28
        )
        adjustButton.frame = NSRect(
            x: (capsuleView.bounds.width - 28) / 2,
            y: 32,
            width: 28,
            height: 28
        )
        chevronView.frame = NSRect(
            x: (nubView.bounds.width - 14) / 2,
            y: (nubView.bounds.height - 18) / 2,
            width: 14,
            height: 18
        )
        updateChevron()
        needsLayout = true
    }

    private func updateChevron() {
        let symbolName: String
        switch edge {
        case .left:
            symbolName = "chevron.right"
        case .right:
            symbolName = "chevron.left"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Show HUD") {
            image.isTemplate = true
            chevronView.image = image
        }
    }

    private func beginDrag(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin
        onDragBegan?()
    }

    private func continueDrag(with event: NSEvent) {
        guard let dragStartLocation,
              let dragStartOrigin else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        let nextOrigin = NSPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY)
        onDragMoved?(nextOrigin)
    }

    private func endDrag(with event: NSEvent) {
        guard dragStartLocation != nil else {
            return
        }

        dragStartLocation = nil
        dragStartOrigin = nil
        onDragEnded?()
    }

    @objc private func toggleLight() {
        onToggleLight?()
    }

    @objc private func openAdjustments() {
        onOpenAdjustments?()
    }
}

final class CompactHUDController {
    private static let edgeInset: CGFloat = 0
    private static let toolbarRevealDuration: TimeInterval = 0.18
    private static let toolbarCollapseDuration: TimeInterval = 0.14
    private static let handoffDuration: TimeInterval = 0.22
    private static let hoverGuardDuration: TimeInterval = 0.12
    private static let pointerMonitorInterval: TimeInterval = 1.0 / 20.0
    private static let pointerPadding: CGFloat = 4

    private let window: CompactHUDWindow
    private let hudView: CompactHUDView
    private let onOpenAdjustments: (HUDEdge, CGFloat) -> Void
    private(set) var isVisible = false
    private var mode: CompactHUDMode = .handle
    private var dockedEdge: HUDEdge = .right
    private var centerY: CGFloat
    private var isTransitioning = false
    private var ignoreHandleHoverUntil: TimeInterval = 0
    private var ignoreToolbarExitUntil: TimeInterval = 0
    private var isDragging = false
    private var pointerMonitorTimer: Timer?

    init(
        isLightOn: Bool,
        onToggleLight: @escaping () -> Void,
        onOpenAdjustments: @escaping (HUDEdge, CGFloat) -> Void
    ) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialCenterY = visibleFrame.midY
        self.centerY = initialCenterY
        self.onOpenAdjustments = onOpenAdjustments

        self.window = CompactHUDWindow(
            contentRect: Self.frame(for: .handle, edge: .right, centerY: initialCenterY, referenceFrame: visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.hudView = CompactHUDView(isLightOn: isLightOn)

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
        hudView.onHandleHover = { [weak self] in
            self?.handleHover()
        }
        hudView.onToolbarEnter = { [weak self] in
            self?.window.alphaValue = 1
        }
        hudView.onToolbarExit = { [weak self] in
            self?.handleToolbarExit()
        }
        hudView.onOpenAdjustments = { [weak self] in
            self?.handoffToAdjustments()
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

    func updateLightState(_ isLightOn: Bool) {
        hudView.updateLightState(isLightOn)
    }

    func hide() {
        isVisible = false
        isTransitioning = false
        isDragging = false
        stopPointerMonitor()
        window.orderOut(nil)
    }

    func showHandle(at edge: HUDEdge? = nil, centerY: CGFloat? = nil, animated: Bool) {
        let nextEdge = edge ?? dockedEdge
        let nextCenterY = centerY ?? self.centerY
        dockedEdge = nextEdge
        self.centerY = nextCenterY
        isVisible = true
        transition(to: .handle, edge: nextEdge, centerY: nextCenterY, animated: animated)
    }

    func showToolbar(at edge: HUDEdge? = nil, centerY: CGFloat? = nil, animated: Bool) {
        let nextEdge = edge ?? dockedEdge
        let nextCenterY = centerY ?? self.centerY
        dockedEdge = nextEdge
        self.centerY = nextCenterY
        isVisible = true
        transition(to: .toolbar, edge: nextEdge, centerY: nextCenterY, animated: animated)
    }

    private func handoffToAdjustments() {
        guard isVisible, !isTransitioning else {
            return
        }

        isTransitioning = true
        let edge = dockedEdge
        let anchorY = centerY
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.handoffDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else {
                return
            }

            self.isTransitioning = false
            self.window.orderOut(nil)
            self.window.alphaValue = 1
            self.onOpenAdjustments(edge, anchorY)
        })
    }

    private func handleHover() {
        guard isVisible,
              mode == .handle,
              !isTransitioning,
              !isDragging,
              ProcessInfo.processInfo.systemUptime >= ignoreHandleHoverUntil else {
            return
        }

        showToolbar(animated: true)
    }

    private func handleToolbarExit() {
        guard isVisible,
              mode == .toolbar,
              !isTransitioning,
              !isDragging,
              ProcessInfo.processInfo.systemUptime >= ignoreToolbarExitUntil else {
            return
        }

        collapseToolbarIfPointerOutside()
    }

    private func collapseToolbarIfPointerOutside() {
        guard mode == .toolbar else {
            return
        }

        let hoverFrame = window.frame.insetBy(dx: -Self.pointerPadding, dy: -Self.pointerPadding)
        guard !hoverFrame.contains(NSEvent.mouseLocation) else {
            return
        }

        showHandle(at: nil, centerY: nil, animated: true)
    }

    private func beginDrag() {
        guard isVisible, !isTransitioning else {
            return
        }

        isDragging = true
        window.hasShadow = false
        ignoreHandleHoverUntil = .greatestFiniteMagnitude
        ignoreToolbarExitUntil = .greatestFiniteMagnitude
    }

    private func move(to origin: NSPoint) {
        guard isDragging else {
            return
        }

        var frame = window.frame
        frame.origin = origin
        window.setFrame(frame, display: true)
    }

    private func endDrag() {
        guard isDragging else {
            return
        }

        isDragging = false
        window.hasShadow = true
        let frame = clampedFrame(window.frame)
        window.setFrame(frame, display: true)

        let edge = nearestHorizontalEdge(for: frame)
        let snapCenterY = frame.midY
        dockedEdge = edge
        centerY = snapCenterY
        transition(to: .handle, edge: edge, centerY: snapCenterY, animated: true)
    }

    private func transition(to mode: CompactHUDMode, edge: HUDEdge, centerY: CGFloat, animated: Bool) {
        let referenceFrame = screen(for: window.frame).visibleFrame
        let targetFrame = Self.frame(for: mode, edge: edge, centerY: centerY, referenceFrame: referenceFrame)
        let duration = mode == .toolbar ? Self.toolbarRevealDuration : Self.toolbarCollapseDuration
        let timing: CAMediaTimingFunctionName = mode == .toolbar ? .easeOut : .easeIn

        self.mode = mode
        hudView.setMode(mode, edge: edge)
        isTransitioning = true

        if !window.isVisible {
            window.setFrame(targetFrame, display: false)
            window.alphaValue = 1
            window.orderFrontRegardless()
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: timing)
                window.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak self] in
                self?.finishTransition(to: mode)
            })
        } else {
            window.setFrame(targetFrame, display: true)
            finishTransition(to: mode)
        }
    }

    private func finishTransition(to mode: CompactHUDMode) {
        isTransitioning = false

        switch mode {
        case .handle:
            stopPointerMonitor()
            ignoreHandleHoverUntil = ProcessInfo.processInfo.systemUptime + Self.hoverGuardDuration
        case .toolbar:
            startPointerMonitorIfNeeded()
            ignoreToolbarExitUntil = ProcessInfo.processInfo.systemUptime + Self.hoverGuardDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverGuardDuration) { [weak self] in
                self?.collapseToolbarIfPointerOutside()
            }
        }
    }

    private func startPointerMonitorIfNeeded() {
        guard pointerMonitorTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: Self.pointerMonitorInterval, repeats: true) { [weak self] _ in
            self?.collapseToolbarIfPointerOutside()
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerMonitorTimer = timer
    }

    private func stopPointerMonitor() {
        pointerMonitorTimer?.invalidate()
        pointerMonitorTimer = nil
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

    private static func frame(for mode: CompactHUDMode, edge: HUDEdge, centerY: CGFloat, referenceFrame: NSRect) -> NSRect {
        let size = mode == .handle ? CompactHUDView.handleSize : CompactHUDView.toolbarWindowSize
        let y = (centerY - size.height / 2).clamped(to: referenceFrame.minY + 10...referenceFrame.maxY - size.height - 10)

        switch edge {
        case .left:
            return NSRect(
                x: referenceFrame.minX + Self.edgeInset,
                y: y,
                width: size.width,
                height: size.height
            )
        case .right:
            return NSRect(
                x: referenceFrame.maxX - size.width - Self.edgeInset,
                y: y,
                width: size.width,
                height: size.height
            )
        }
    }
}
