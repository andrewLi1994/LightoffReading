import AppKit

final class SpotlightOverlayView: NSView {
    var config: SpotlightConfig

    private var effectiveOpacity: CGFloat = 0
    private var effectiveSpotlightWidth: CGFloat = 0
    private var effectiveSpotlightHeight: CGFloat = 0
    private var effectiveFeather: CGFloat = 0
    private var spotlightCenter: NSPoint?
    private var transitionFromShape: SpotlightShape?
    private var shapeTransitionProgress: CGFloat = 1
    private var edgeGlowStyle: EdgeGlowStyle = .off
    private var edgeGlowPhase: CGFloat = 0

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
        feather: CGFloat,
        shape: SpotlightShape,
        transitionFromShape: SpotlightShape?,
        shapeTransitionProgress: CGFloat,
        edgeGlowStyle: EdgeGlowStyle,
        edgeGlowPhase: CGFloat
    ) {
        let clampedOpacity = opacity.clamped(to: 0...1)
        let clampedWidth = max(1, width)
        let clampedHeight = max(1, height)
        let clampedFeather = max(0, feather)
        let clampedTransitionProgress = shapeTransitionProgress.clamped(to: 0...1)
        let clampedGlowPhase = edgeGlowPhase.clamped(to: 0...1)
        let centerChanged: Bool

        switch (self.spotlightCenter, spotlightCenter) {
        case let (current?, next?):
            centerChanged = current.distance(to: next) > 0.5
        case (nil, nil):
            centerChanged = false
        default:
            centerChanged = true
        }

        let shapeChanged = config.shape != shape
            || self.transitionFromShape != transitionFromShape
            || abs(self.shapeTransitionProgress - clampedTransitionProgress) > 0.001

        let shouldRedraw = abs(effectiveOpacity - clampedOpacity) > 0.001
            || abs(effectiveSpotlightWidth - clampedWidth) > 0.5
            || abs(effectiveSpotlightHeight - clampedHeight) > 0.5
            || abs(effectiveFeather - clampedFeather) > 0.5
            || centerChanged
            || shapeChanged
            || self.edgeGlowStyle != edgeGlowStyle
            || abs(self.edgeGlowPhase - clampedGlowPhase) > 0.001

        effectiveOpacity = clampedOpacity
        effectiveSpotlightWidth = clampedWidth
        effectiveSpotlightHeight = clampedHeight
        effectiveFeather = clampedFeather
        self.spotlightCenter = spotlightCenter
        config.shape = shape
        self.transitionFromShape = transitionFromShape
        self.shapeTransitionProgress = clampedTransitionProgress
        self.edgeGlowStyle = edgeGlowStyle
        self.edgeGlowPhase = clampedGlowPhase

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
        drawEdgeGlow(in: context)

        guard let spotlightCenter else {
            return
        }

        context.saveGState()
        context.setBlendMode(.destinationOut)

        let toShape = config.shape
        if let fromShape = transitionFromShape,
           shapeTransitionProgress < 0.999,
           fromShape != toShape {
            drawSpotlightShape(
                in: context,
                shape: fromShape,
                center: spotlightCenter,
                alpha: 1 - shapeTransitionProgress
            )
            drawSpotlightShape(
                in: context,
                shape: toShape,
                center: spotlightCenter,
                alpha: shapeTransitionProgress
            )
        } else {
            drawSpotlightShape(
                in: context,
                shape: toShape,
                center: spotlightCenter,
                alpha: 1
            )
        }

        context.restoreGState()
    }

    private func drawEdgeGlow(in context: CGContext) {
        guard edgeGlowStyle.intensity > 0.001,
              edgeGlowStyle.thickness > 0.5,
              edgeGlowStyle.softness > 0.5 else {
            return
        }

        let pulse = 1 + edgeGlowStyle.pulseAmplitude * sin(edgeGlowPhase * .pi * 2)
        let alpha = (edgeGlowStyle.intensity * pulse).clamped(to: 0...1)
        let thickness = edgeGlowStyle.thickness
        let softness = edgeGlowStyle.softness
        let color = edgeGlowStyle.color.nsColor

        drawEdgeGradient(
            in: context,
            rect: NSRect(x: 0, y: bounds.height - thickness - softness, width: bounds.width, height: thickness + softness),
            start: NSPoint(x: 0, y: bounds.height),
            end: NSPoint(x: 0, y: bounds.height - thickness - softness),
            color: color,
            alpha: alpha
        )
        drawEdgeGradient(
            in: context,
            rect: NSRect(x: 0, y: 0, width: bounds.width, height: thickness + softness),
            start: NSPoint(x: 0, y: 0),
            end: NSPoint(x: 0, y: thickness + softness),
            color: color,
            alpha: alpha
        )
        drawEdgeGradient(
            in: context,
            rect: NSRect(x: 0, y: 0, width: thickness + softness, height: bounds.height),
            start: NSPoint(x: 0, y: 0),
            end: NSPoint(x: thickness + softness, y: 0),
            color: color,
            alpha: alpha
        )
        drawEdgeGradient(
            in: context,
            rect: NSRect(x: bounds.width - thickness - softness, y: 0, width: thickness + softness, height: bounds.height),
            start: NSPoint(x: bounds.width, y: 0),
            end: NSPoint(x: bounds.width - thickness - softness, y: 0),
            color: color,
            alpha: alpha
        )
    }

    private func drawEdgeGradient(
        in context: CGContext,
        rect: NSRect,
        start: NSPoint,
        end: NSPoint,
        color: NSColor,
        alpha: CGFloat
    ) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                color.withAlphaComponent(alpha).cgColor,
                color.withAlphaComponent(alpha * 0.45).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray,
            locations: [0, 0.35, 1]
        ) else {
            return
        }

        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(
            gradient,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private func drawSpotlightShape(
        in context: CGContext,
        shape: SpotlightShape,
        center: NSPoint,
        alpha: CGFloat
    ) {
        guard alpha > 0.001 else {
            return
        }

        let resolvedSize = resolvedSpotlightSize(for: shape)

        switch shape {
        case .ellipse:
            drawEllipse(
                in: context,
                center: center,
                width: resolvedSize.width,
                height: resolvedSize.height,
                alpha: alpha
            )
        case .rectangle, .horizontalStrip, .verticalStrip:
            drawSoftRect(
                in: context,
                rect: rect(centeredAt: center, width: resolvedSize.width, height: resolvedSize.height),
                alpha: alpha
            )
        }
    }

    private func drawEllipse(
        in context: CGContext,
        center: NSPoint,
        width: CGFloat,
        height: CGFloat,
        alpha: CGFloat
    ) {
        let baseRadius = max(1, min(width, height) / 2)
        let scaleX = max(0.01, width / (baseRadius * 2))
        let scaleY = max(0.01, height / (baseRadius * 2))
        let feather = cappedFeather(forShortDimension: min(width, height))
        let gradientRadius = max(1, baseRadius + feather)
        let solidStop = max(0.01, min(0.98, baseRadius / gradientRadius))
        let colors = [
            NSColor.white.withAlphaComponent(alpha).cgColor,
            NSColor.white.withAlphaComponent(alpha).cgColor,
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

    private func drawSoftRect(in context: CGContext, rect: NSRect, alpha: CGFloat) {
        let feather = cappedFeather(forShortDimension: min(rect.width, rect.height))
        let cornerRadius = min(16.0, min(rect.width, rect.height) / 2.0)

        context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.fillPath()

        guard feather > 0.5 else {
            return
        }

        drawRectOuterFeather(
            in: context,
            rect: rect,
            feather: feather,
            cornerRadius: cornerRadius,
            alpha: alpha
        )
    }

    private func drawRectOuterFeather(
        in context: CGContext,
        rect: NSRect,
        feather: CGFloat,
        cornerRadius: CGFloat,
        alpha: CGFloat
    ) {
        let maxSteps = 72
        let steps = max(8, min(maxSteps, Int(feather.rounded(.up))))
        let stepWidth = feather / CGFloat(steps)

        context.saveGState()
        context.setLineJoin(.miter)

        for index in 0..<steps {
            let progress = CGFloat(index) / CGFloat(max(1, steps - 1))
            let distance = CGFloat(index) * stepWidth + stepWidth / 2
            let featherAlpha = pow(1 - progress, 1.8) * alpha
            let strokeRect = rect.insetBy(dx: -distance, dy: -distance)
            let outerRadius = cornerRadius + distance

            context.setStrokeColor(NSColor.white.withAlphaComponent(featherAlpha).cgColor)
            context.setLineWidth(stepWidth)

            let path = CGPath(roundedRect: strokeRect, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil)
            context.addPath(path)
            context.strokePath()
        }

        context.restoreGState()
    }

    private func cappedFeather(forShortDimension shortDimension: CGFloat) -> CGFloat {
        min(effectiveFeather, max(1, shortDimension * 0.42))
    }

    private func resolvedSpotlightSize(for shape: SpotlightShape) -> CGSize {
        var width = effectiveSpotlightWidth
        var height = effectiveSpotlightHeight

        switch shape {
        case .horizontalStrip:
            width = bounds.width + effectiveFeather * 4
        case .verticalStrip:
            height = bounds.height + effectiveFeather * 4
        case .ellipse, .rectangle:
            break
        }

        return CGSize(width: width, height: height)
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
        feather: CGFloat,
        shape: SpotlightShape,
        transitionFromShape: SpotlightShape?,
        shapeTransitionProgress: CGFloat,
        edgeGlowStyle: EdgeGlowStyle,
        edgeGlowPhase: CGFloat
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
            feather: feather,
            shape: shape,
            transitionFromShape: transitionFromShape,
            shapeTransitionProgress: shapeTransitionProgress,
            edgeGlowStyle: edgeGlowStyle,
            edgeGlowPhase: edgeGlowPhase
        )
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

    private struct ConfigAnimation {
        let fromConfig: SpotlightConfig
        let toConfig: SpotlightConfig
        let startTime: TimeInterval
        let duration: TimeInterval
    }

    private struct ShapeTransitionState {
        let config: SpotlightConfig
        let fromShape: SpotlightShape?
        let progress: CGFloat
    }

    private struct ActivityRenderState {
        let spotlightOpacityMultiplier: CGFloat
        let spotlightSizeDelta: CGFloat
        let spotlightFeatherDelta: CGFloat
        let edgeGlowStyle: EdgeGlowStyle
        let edgeGlowPhase: CGFloat
    }

    private static let enableDuration: TimeInterval = 0.65
    private static let disableDuration: TimeInterval = 0.75
    private static let shapeTransitionDuration: TimeInterval = 0.5
    private static let activityEnterTransitionDuration: TimeInterval = 0.38
    private static let doneHighlightDuration: TimeInterval = 0.28
    private static let doneExitTransitionDuration: TimeInterval = 0.75

    private var config: SpotlightConfig
    private var windowsByDisplayID: [CGDirectDisplayID: SpotlightOverlayWindow] = [:]
    private var lastMouseLocation: NSPoint?
    private var pollTimer: Timer?
    private var state: OverlayState = .off
    private var visualProgress: CGFloat = 0
    private var animation: OverlayAnimation?
    private var configAnimation: ConfigAnimation?
    private var activityStatus: ActivityStatus = .idle
    private var displayedEdgeGlowStyle: EdgeGlowStyle = .off
    private var targetEdgeGlowStyle: EdgeGlowStyle = .off
    private var activityTransitionStartTime: TimeInterval?
    private var activityTransitionDuration: TimeInterval = 0.38
    private var activityTransitionFromStyle: EdgeGlowStyle = .off
    private var doneHighlightEndTime: TimeInterval?
    private var postDoneStatus: ActivityStatus = .idle

    var onActivityStatusSettled: ((ActivityStatus) -> Void)?

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

        syncWindows()
        windowsByDisplayID.values.forEach { $0.orderFrontRegardless() }
        startTimerIfNeeded()
        startAnimation(to: enabled ? 1 : 0, baseDuration: enabled ? Self.enableDuration : Self.disableDuration)
    }

    func update(config: SpotlightConfig) {
        let now = ProcessInfo.processInfo.systemUptime
        let currentConfig = currentShapeTransitionState(now: now).config

        self.config = config
        windowsByDisplayID.values.forEach { $0.update(config: config) }

        if state != .off, currentConfig.shape != config.shape {
            startTimerIfNeeded()
            configAnimation = ConfigAnimation(
                fromConfig: currentConfig,
                toConfig: config,
                startTime: now,
                duration: Self.shapeTransitionDuration
            )
        } else {
            configAnimation = nil
        }

        if state != .off {
            tick(force: true)
        }
    }

    func update(activityStatus: ActivityStatus) {
        guard self.activityStatus != activityStatus || activityStatus == .done else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        displayedEdgeGlowStyle = currentDisplayedEdgeGlowStyle(now: now)

        if self.activityStatus == .done,
           activityStatus != .done,
           doneHighlightEndTime != nil {
            if activityStatus == .needsApproval {
                self.activityStatus = activityStatus
                postDoneStatus = activityStatus
                doneHighlightEndTime = nil
                beginActivityTransition(to: edgeGlowStyle(for: activityStatus), from: displayedEdgeGlowStyle, now: now, duration: Self.activityEnterTransitionDuration)

                if state != .off {
                    startTimerIfNeeded()
                    tick(force: true)
                }
                return
            }

            postDoneStatus = activityStatus

            if state != .off {
                startTimerIfNeeded()
                tick(force: true)
            }
            return
        }

        if activityStatus == .done {
            self.activityStatus = .done
            postDoneStatus = .idle
            doneHighlightEndTime = now + Self.doneHighlightDuration
            beginActivityTransition(to: doneGlowStyle, from: displayedEdgeGlowStyle, now: now, duration: Self.activityEnterTransitionDuration)
        } else {
            postDoneStatus = activityStatus
            doneHighlightEndTime = nil
            self.activityStatus = activityStatus
            beginActivityTransition(
                to: activityStatus == .idle ? fadeOutStyle(from: displayedEdgeGlowStyle) : edgeGlowStyle(for: activityStatus),
                from: displayedEdgeGlowStyle,
                now: now,
                duration: activityStatus == .idle ? Self.doneExitTransitionDuration : Self.activityEnterTransitionDuration
            )
        }

        if state != .off {
            startTimerIfNeeded()
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
        let now = ProcessInfo.processInfo.systemUptime
        let animationChanged = advanceAnimation(now: now)
        let configAnimationChanged = advanceConfigAnimation(now: now)
        let activityAnimationChanged = advanceActivityAnimation(now: now)

        if state == .off {
            return
        }

        updateRenderState(
            force: force || animationChanged || configAnimationChanged || activityAnimationChanged || shouldContinueActivityAnimation(now: now),
            now: now
        )
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

    private func advanceConfigAnimation(now: TimeInterval) -> Bool {
        guard let configAnimation else {
            return false
        }

        let rawProgress = ((now - configAnimation.startTime) / configAnimation.duration).clamped(to: 0...1)

        if rawProgress >= 1 {
            self.configAnimation = nil
        }

        return true
    }

    private func advanceActivityAnimation(now: TimeInterval) -> Bool {
        if let doneHighlightEndTime, now >= doneHighlightEndTime {
            self.doneHighlightEndTime = nil
            displayedEdgeGlowStyle = currentDisplayedEdgeGlowStyle(now: now)
            activityStatus = postDoneStatus
            beginActivityTransition(
                to: postDoneStatus == .idle ? fadeOutStyle(from: displayedEdgeGlowStyle) : edgeGlowStyle(for: postDoneStatus),
                from: displayedEdgeGlowStyle,
                now: now,
                duration: postDoneStatus == .idle ? Self.doneExitTransitionDuration : Self.activityEnterTransitionDuration
            )
            return true
        }

        return false
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
                feather: config.feather,
                shape: config.shape,
                transitionFromShape: nil,
                shapeTransitionProgress: 1,
                edgeGlowStyle: .off,
                edgeGlowPhase: 0
            )
            $0.orderOut(nil)
        }
    }

    private func updateRenderState(force: Bool, now: TimeInterval) {
        let mouseLocation = NSEvent.mouseLocation

        if !force, let lastMouseLocation, lastMouseLocation.distance(to: mouseLocation) < 0.5 {
            return
        }

        lastMouseLocation = mouseLocation

        guard let activeScreen = screen(containing: mouseLocation) ?? NSScreen.main else {
            return
        }

        let activeDisplayID = activeScreen.displayID
        let shapeState = currentShapeTransitionState(now: now)
        let spotlightPoint = clampedSpotlightPoint(for: mouseLocation, on: activeScreen, shapeState: shapeState)
        let activityEffect = currentActivityRenderState(now: now)
        let opacity = (shapeState.config.opacity * activityEffect.spotlightOpacityMultiplier).clamped(to: 0...0.95) * visualProgress

        for (displayID, window) in windowsByDisplayID {
            if displayID == activeDisplayID {
                let coverSize = window.screenCoveringSize
                let expandedFeather = max(shapeState.config.feather, min(coverSize.width, coverSize.height) * 0.08)
                let baseWidth = coverSize.width + (shapeState.config.width - coverSize.width) * visualProgress
                let baseHeight = coverSize.height + (shapeState.config.height - coverSize.height) * visualProgress
                let baseFeather = expandedFeather + (shapeState.config.feather - expandedFeather) * visualProgress
                let width = baseWidth + activityEffect.spotlightSizeDelta
                let height = baseHeight + activityEffect.spotlightSizeDelta * 0.45
                let feather = baseFeather + activityEffect.spotlightFeatherDelta

                window.applyRenderState(
                    opacity: opacity,
                    globalSpotlightPoint: spotlightPoint,
                    width: width,
                    height: height,
                    feather: feather,
                    shape: shapeState.config.shape,
                    transitionFromShape: shapeState.fromShape,
                    shapeTransitionProgress: shapeState.progress,
                    edgeGlowStyle: activityEffect.edgeGlowStyle,
                    edgeGlowPhase: activityEffect.edgeGlowPhase
                )
            } else {
                window.applyRenderState(
                    opacity: opacity,
                    globalSpotlightPoint: nil,
                    width: shapeState.config.width,
                    height: shapeState.config.height,
                    feather: shapeState.config.feather,
                    shape: shapeState.config.shape,
                    transitionFromShape: shapeState.fromShape,
                    shapeTransitionProgress: shapeState.progress,
                    edgeGlowStyle: activityEffect.edgeGlowStyle,
                    edgeGlowPhase: activityEffect.edgeGlowPhase
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

    private func currentActivityRenderState(now: TimeInterval) -> ActivityRenderState {
        let edgeGlowStyle = currentDisplayedEdgeGlowStyle(now: now)
        displayedEdgeGlowStyle = edgeGlowStyle
        let pulse = (sin(now * edgeGlowStyle.pulseSpeed) + 1) / 2

        switch activityStatus {
        case .idle:
            return ActivityRenderState(
                spotlightOpacityMultiplier: 1,
                spotlightSizeDelta: 0,
                spotlightFeatherDelta: 0,
                edgeGlowStyle: edgeGlowStyle,
                edgeGlowPhase: CGFloat(pulse)
            )
        case .running:
            return ActivityRenderState(
                spotlightOpacityMultiplier: 1,
                spotlightSizeDelta: 0,
                spotlightFeatherDelta: 0,
                edgeGlowStyle: edgeGlowStyle,
                edgeGlowPhase: CGFloat(pulse)
            )
        case .done:
            return ActivityRenderState(
                spotlightOpacityMultiplier: 1,
                spotlightSizeDelta: 0,
                spotlightFeatherDelta: 0,
                edgeGlowStyle: edgeGlowStyle,
                edgeGlowPhase: CGFloat(pulse)
            )
        case .needsApproval:
            return ActivityRenderState(
                spotlightOpacityMultiplier: 1,
                spotlightSizeDelta: 0,
                spotlightFeatherDelta: 0,
                edgeGlowStyle: edgeGlowStyle,
                edgeGlowPhase: CGFloat(pulse)
            )
        }
    }

    private func currentDisplayedEdgeGlowStyle(now: TimeInterval) -> EdgeGlowStyle {
        guard let activityTransitionStartTime else {
            return targetEdgeGlowStyle
        }

        let rawProgress = ((now - activityTransitionStartTime) / activityTransitionDuration).clamped(to: 0...1)
        let easedProgress = easeInOutCubic(CGFloat(rawProgress))
        let style = activityTransitionFromStyle.interpolated(to: targetEdgeGlowStyle, progress: easedProgress)

        if rawProgress >= 1 {
            self.activityTransitionStartTime = nil
            if targetEdgeGlowStyle.intensity <= 0.001 {
                self.targetEdgeGlowStyle = .off
                self.activityTransitionFromStyle = .off
                onActivityStatusSettled?(.idle)
                return .off
            }

            self.activityTransitionFromStyle = targetEdgeGlowStyle
            if activityStatus != .done {
                onActivityStatusSettled?(activityStatus)
            }
        }

        return style
    }

    private func beginActivityTransition(to targetStyle: EdgeGlowStyle, from sourceStyle: EdgeGlowStyle, now: TimeInterval, duration: TimeInterval) {
        activityTransitionFromStyle = sourceStyle
        targetEdgeGlowStyle = targetStyle
        activityTransitionStartTime = now
        activityTransitionDuration = duration
    }

    private func fadeOutStyle(from style: EdgeGlowStyle) -> EdgeGlowStyle {
        EdgeGlowStyle(
            color: style.color,
            intensity: 0,
            thickness: style.thickness,
            softness: style.softness,
            pulseAmplitude: 0,
            pulseSpeed: style.pulseSpeed
        )
    }

    private func shouldContinueActivityAnimation(now: TimeInterval) -> Bool {
        if activityStatus != .idle {
            return true
        }

        return currentDisplayedEdgeGlowStyle(now: now) != .off
    }

    private func edgeGlowStyle(for status: ActivityStatus) -> EdgeGlowStyle {
        switch status {
        case .idle:
            return .off
        case .running:
            return EdgeGlowStyle(
                color: RGBColor(red: 0.16, green: 0.82, blue: 1.0),
                intensity: 0.36,
                thickness: 14,
                softness: 44,
                pulseAmplitude: 0.12,
                pulseSpeed: 2.1
            )
        case .done:
            return doneGlowStyle
        case .needsApproval:
            return EdgeGlowStyle(
                color: RGBColor(red: 1.0, green: 0.78, blue: 0.22),
                intensity: 0.56,
                thickness: 18,
                softness: 56,
                pulseAmplitude: 0.18,
                pulseSpeed: 3.4
            )
        }
    }

    private var doneGlowStyle: EdgeGlowStyle {
        EdgeGlowStyle(
            color: RGBColor(red: 0.32, green: 1.0, blue: 0.58),
            intensity: 0.62,
            thickness: 22,
            softness: 76,
            pulseAmplitude: 0,
            pulseSpeed: 1
        )
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func currentShapeTransitionState(now: TimeInterval) -> ShapeTransitionState {
        guard let configAnimation else {
            return ShapeTransitionState(config: config, fromShape: nil, progress: 1)
        }

        let rawProgress = ((now - configAnimation.startTime) / configAnimation.duration).clamped(to: 0...1)
        let easedProgress = easeInOutCubic(CGFloat(rawProgress))

        if rawProgress >= 1 {
            return ShapeTransitionState(config: configAnimation.toConfig, fromShape: nil, progress: 1)
        }

        return ShapeTransitionState(
            config: configAnimation.fromConfig.interpolated(to: configAnimation.toConfig, progress: easedProgress),
            fromShape: configAnimation.fromConfig.shape,
            progress: easedProgress
        )
    }

    private func clampedSpotlightPoint(
        for mouseLocation: NSPoint,
        on screen: NSScreen,
        shapeState: ShapeTransitionState
    ) -> NSPoint {
        let frame = screen.frame
        let proposed = NSPoint(
            x: mouseLocation.x + shapeState.config.cursorXOffset,
            y: mouseLocation.y + shapeState.config.cursorYOffset
        )

        var result = NSPoint(
            x: proposed.x.clamped(to: frame.minX...frame.maxX),
            y: proposed.y.clamped(to: frame.minY...frame.maxY)
        )

        let horizontalLock = stripLockWeight(
            for: .horizontalStrip,
            from: shapeState.fromShape,
            to: shapeState.config.shape,
            progress: shapeState.progress
        )
        let verticalLock = stripLockWeight(
            for: .verticalStrip,
            from: shapeState.fromShape,
            to: shapeState.config.shape,
            progress: shapeState.progress
        )

        result.x = result.x + (frame.midX - result.x) * horizontalLock
        result.y = result.y + (frame.midY - result.y) * verticalLock

        return result
    }

    private func stripLockWeight(
        for stripShape: SpotlightShape,
        from sourceShape: SpotlightShape?,
        to targetShape: SpotlightShape,
        progress: CGFloat
    ) -> CGFloat {
        let fromMatches = sourceShape == stripShape
        let toMatches = targetShape == stripShape

        switch (fromMatches, toMatches) {
        case (true, true):
            return 1
        case (true, false):
            return 1 - progress
        case (false, true):
            return progress
        case (false, false):
            return 0
        }
    }
}
