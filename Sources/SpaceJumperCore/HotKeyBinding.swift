import Carbon.HIToolbox

/// One global shortcut and what it does. The app registers these with
/// `RegisterEventHotKey`; key codes and modifiers are Carbon's.
public struct HotKeyBinding: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case move(Direction)
        case desktop(Int)
    }

    /// As shown in the menu and the log, e.g. "⌃←" or "⌃3".
    public let name: String
    public let keyCode: Int
    public let prefix: ModifierPrefix
    public let action: Action

    public var modifiers: Int { prefix.carbonModifiers }

    /// The `CGEventFlags` of the key-down event the keyboard sends for this
    /// shortcut. Arrow keys add the fn and numeric-pad flags to every event.
    public var keyboardEventFlags: UInt64 {
        prefix.eventFlags | (Self.arrowKeyCodes.contains(keyCode) ? EventFlag.function | EventFlag.numericPad : 0)
    }

    static let arrowKeyCodes: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]

    /// Key codes of the digits 1–9 on an ANSI keyboard, in order.
    static let digitKeyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    /// Prefix-← and prefix-→.
    public static func arrowKeys(_ prefix: ModifierPrefix) -> [HotKeyBinding] {
        [HotKeyBinding(name: "\(prefix.symbols)←", keyCode: kVK_LeftArrow, prefix: prefix, action: .move(.left)),
         HotKeyBinding(name: "\(prefix.symbols)→", keyCode: kVK_RightArrow, prefix: prefix, action: .move(.right))]
    }

    /// Prefix-1 … prefix-9.
    public static func desktopKeys(_ prefix: ModifierPrefix) -> [HotKeyBinding] {
        digitKeyCodes.enumerated().map { index, keyCode in
            HotKeyBinding(name: "\(prefix.symbols)\(index + 1)", keyCode: keyCode, prefix: prefix, action: .desktop(index + 1))
        }
    }

    /// The bindings for the groups the user has switched on.
    public static func enabled(prefix: ModifierPrefix, arrowKeys arrows: Bool, desktopKeys desktops: Bool) -> [HotKeyBinding] {
        (arrows ? arrowKeys(prefix) : []) + (desktops ? desktopKeys(prefix) : [])
    }
}
