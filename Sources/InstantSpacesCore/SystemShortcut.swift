import Carbon.HIToolbox

/// An enabled macOS keyboard shortcut ("symbolic hotkey"), as SkyLight reports
/// it: a number, a key code, `CGEventFlags` and an internal name.
public struct SystemShortcut: Equatable, Sendable {
    public let id: Int32
    public let keyCode: Int
    public let flags: UInt64
    /// SkyLight's internal name, e.g. "WindowTileLeftHalf"; nil until looked up.
    public var identifier: String?

    public init(id: Int32, keyCode: Int, flags: UInt64, identifier: String? = nil) {
        self.id = id
        self.keyCode = keyCode
        self.flags = flags
        self.identifier = identifier
    }

    /// Where System Settings lists a shortcut: its label and its section under
    /// Keyboard → Keyboard Shortcuts.
    public struct Label: Equatable, Sendable {
        public let title: String
        public let section: String
    }

    /// The System Settings label for the internal names InstantSpaces knows.
    /// Each title is the English text of System Settings' table
    /// (`KeyboardSettings.appex/Contents/Resources/DefaultShortcutsTable.loctable`).
    public var label: Label? {
        guard let identifier else { return nil }
        switch identifier {
        case "WorkspacesLeft": return Label(title: "Move left a Space", section: "Mission Control")
        case "WorkspacesRight": return Label(title: "Move right a Space", section: "Mission Control")
        case "WindowTileLeftHalf": return Label(title: "Tile Left Half", section: "Windows")
        case "WindowTileRightHalf": return Label(title: "Tile Right Half", section: "Windows")
        case "WindowTileTopHalf": return Label(title: "Tile Top Half", section: "Windows")
        case "WindowTileBottomHalf": return Label(title: "Tile Bottom Half", section: "Windows")
        case "WindowArrangeLeftAndRight": return Label(title: "Arrange Left and Right", section: "Windows")
        case "WindowArrangeRightAndLeft": return Label(title: "Arrange Right and Left", section: "Windows")
        case "WindowArrangeTopAndBottom": return Label(title: "Arrange Top and Bottom", section: "Windows")
        case "WindowArrangeBottomAndTop": return Label(title: "Arrange Bottom and Top", section: "Windows")
        default:
            if identifier.hasPrefix("Workspaces"), let number = Int(identifier.dropFirst("Workspaces".count)) {
                return Label(title: "Switch to Desktop \(number)", section: "Mission Control")
            }
            return nil
        }
    }

    /// E.g. "“Tile Left Half” (Windows)", or "macOS shortcut 199
    /// (SplitViewMakeLeft)" when System Settings' label is not known.
    public var name: String {
        if let label { return "“\(label.title)” (\(label.section))" }
        return "macOS shortcut \(id)" + (identifier.map { " (\($0))" } ?? "")
    }
}

/// A binding of InstantSpaces that a macOS shortcut also reacts to.
public struct ShortcutClash: Equatable, Sendable {
    public let binding: HotKeyBinding
    public let shortcut: SystemShortcut

    /// E.g. "⌃← also triggers “Tile Left Half” (Windows)".
    public var description: String {
        "\(binding.name) also triggers \(shortcut.name)"
    }

    /// The clashes among `bindings`. Shortcuts on other keys are skipped;
    /// for the rest, `matches` decides, which in the app asks WindowServer
    /// with the key event the keyboard would send.
    public static func find(_ bindings: [HotKeyBinding], in shortcuts: [SystemShortcut],
                            matches: (HotKeyBinding, SystemShortcut) -> Bool) -> [ShortcutClash] {
        bindings.flatMap { binding in
            shortcuts
                .filter { $0.keyCode == binding.keyCode && matches(binding, $0) }
                .map { ShortcutClash(binding: binding, shortcut: $0) }
        }
    }
}
