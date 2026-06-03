import AppKit

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
            shapeKey: SpotlightShape.horizontalStrip.rawValue,
            radiusKey: 120.0,
            widthKey: 880.0,
            heightKey: 41.0,
            featherKey: 44.0,
            opacityKey: 0.62,
            cursorXOffsetKey: -220.0,
            cursorYOffsetKey: 20.0
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
