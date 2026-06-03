import AppKit
import Carbon.HIToolbox

enum SpotlightShape: String, CaseIterable {
    case ellipse
    case rectangle
    case horizontalStrip
    case verticalStrip

    var displayName: String {
        switch self {
        case .ellipse:
            return "Ellipse"
        case .rectangle:
            return "Rectangle"
        case .horizontalStrip:
            return "Full Width"
        case .verticalStrip:
            return "Full Height"
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

extension SpotlightConfig {
    func interpolated(to other: SpotlightConfig, progress: CGFloat) -> SpotlightConfig {
        let clampedProgress = progress.clamped(to: 0...1)

        func mix(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
            lhs + (rhs - lhs) * clampedProgress
        }

        return SpotlightConfig(
            shape: other.shape,
            width: mix(width, other.width),
            height: mix(height, other.height),
            feather: mix(feather, other.feather),
            opacity: mix(opacity, other.opacity),
            cursorXOffset: mix(cursorXOffset, other.cursorXOffset),
            cursorYOffset: mix(cursorYOffset, other.cursorYOffset)
        )
    }
}

struct HotKeyDefinition: Equatable {
    static let defaultValue = HotKeyDefinition(
        keyCode: UInt32(kVK_ANSI_Slash),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        displayKey: "/"
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

enum HUDEdge {
    case left
    case right
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }

        return number.uint32Value
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension NSPoint {
    func distance(to point: NSPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}

extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
