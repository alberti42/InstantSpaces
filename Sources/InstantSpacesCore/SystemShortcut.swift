import Carbon.HIToolbox

/// An enabled macOS keyboard shortcut ("symbolic hotkey"), as SkyLight reports
/// it: an ID, a key code and `CGEventFlags`.
public struct SystemShortcut: Equatable, Sendable {
    public let id: Int32
    public let keyCode: Int
    public let flags: UInt64

    public init(id: Int32, keyCode: Int, flags: UInt64) {
        self.id = id
        self.keyCode = keyCode
        self.flags = flags
    }

    /// The name System Settings shows, for the shortcuts InstantSpaces knows;
    /// otherwise the ID. SkyLight does not report names.
    public var name: String {
        switch id {
        case 79: "Move left a space"
        case 81: "Move right a space"
        case 118...133: "Switch to Desktop \(id - 117)"
        default: "macOS shortcut \(id)"
        }
    }

    static let arrowKeyCodes: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]

    /// Whether pressing `binding` also triggers this shortcut. Shift, Control,
    /// Option and Command must match. Arrow-key events always carry the fn flag,
    /// so for arrows the flag cannot tell ⌃← from fn⌃← and is ignored; for
    /// other keys a shortcut that needs fn does not clash.
    public func clashes(with binding: HotKeyBinding) -> Bool {
        guard keyCode == binding.keyCode,
              flags & EventFlag.modifiers == binding.prefix.eventFlags
        else { return false }
        return Self.arrowKeyCodes.contains(keyCode) || flags & EventFlag.function == 0
    }
}

/// A binding of InstantSpaces that a macOS shortcut also uses.
public struct ShortcutClash: Equatable, Sendable {
    public let binding: HotKeyBinding
    public let shortcut: SystemShortcut

    /// E.g. "⌃← is also macOS's “Move left a space”".
    public var description: String {
        "\(binding.name) is also used by macOS (\(shortcut.name))"
    }

    public static func find(_ bindings: [HotKeyBinding], in shortcuts: [SystemShortcut]) -> [ShortcutClash] {
        bindings.flatMap { binding in
            shortcuts.filter { $0.clashes(with: binding) }.map { ShortcutClash(binding: binding, shortcut: $0) }
        }
    }
}
