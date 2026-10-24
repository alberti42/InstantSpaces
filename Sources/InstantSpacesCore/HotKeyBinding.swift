import Carbon.HIToolbox

/// One global shortcut and what it does. The app registers these with
/// `RegisterEventHotKey`; key codes and modifiers are Carbon's.
public struct HotKeyBinding: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case move(Direction)
        case desktop(Int)
    }

    /// As shown in the menu and the log, e.g. "⌃←" or "⌃⌘3".
    public let name: String
    public let keyCode: Int
    public let modifiers: Int
    public let action: Action

    /// Key codes of the digits 1–9 on an ANSI keyboard, in order.
    static let digitKeyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    /// ⌃← and ⌃→.
    public static let arrowKeys = [
        HotKeyBinding(name: "⌃←", keyCode: kVK_LeftArrow, modifiers: controlKey, action: .move(.left)),
        HotKeyBinding(name: "⌃→", keyCode: kVK_RightArrow, modifiers: controlKey, action: .move(.right)),
    ]

    /// ⌃⌘1 … ⌃⌘9.
    public static let desktopKeys = digitKeyCodes.enumerated().map { index, keyCode in
        HotKeyBinding(name: "⌃⌘\(index + 1)", keyCode: keyCode, modifiers: controlKey | cmdKey, action: .desktop(index + 1))
    }

    /// The bindings for the groups the user has switched on.
    public static func enabled(arrowKeys arrows: Bool, desktopKeys desktops: Bool) -> [HotKeyBinding] {
        (arrows ? arrowKeys : []) + (desktops ? desktopKeys : [])
    }
}
