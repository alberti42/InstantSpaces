import Carbon.HIToolbox

/// The modifier keys shared by all shortcuts: the arrows and the digits 1–9.
public enum ModifierPrefix: String, CaseIterable, Sendable {
    case control
    case controlOption
    case controlCommand
    case optionCommand
    case controlOptionCommand

    /// ⌃, as in macOS's own Mission Control shortcuts (⌃← ⌃→, ⌃1 … ⌃9).
    public static let `default` = ModifierPrefix.control

    /// In the order macOS writes modifiers: ⌃ ⌥ ⇧ ⌘.
    public var symbols: String {
        switch self {
        case .control: "⌃"
        case .controlOption: "⌃⌥"
        case .controlCommand: "⌃⌘"
        case .optionCommand: "⌥⌘"
        case .controlOptionCommand: "⌃⌥⌘"
        }
    }

    /// Modifiers for `RegisterEventHotKey`.
    public var carbonModifiers: Int {
        switch self {
        case .control: controlKey
        case .controlOption: controlKey | optionKey
        case .controlCommand: controlKey | cmdKey
        case .optionCommand: optionKey | cmdKey
        case .controlOptionCommand: controlKey | optionKey | cmdKey
        }
    }

    /// The same modifiers as `CGEventFlags`, the form in which SkyLight reports
    /// system shortcuts.
    public var eventFlags: UInt64 {
        var flags: UInt64 = 0
        let modifiers = carbonModifiers
        if modifiers & controlKey != 0 { flags |= EventFlag.control }
        if modifiers & optionKey != 0 { flags |= EventFlag.option }
        if modifiers & cmdKey != 0 { flags |= EventFlag.command }
        return flags
    }
}

/// `CGEventFlags` bits, without importing CoreGraphics into the tests.
enum EventFlag {
    static let shift: UInt64 = 0x20000
    static let control: UInt64 = 0x40000
    static let option: UInt64 = 0x80000
    static let command: UInt64 = 0x100000
    /// Set on every arrow-key event, with `function`.
    static let numericPad: UInt64 = 0x200000
    /// Set by the fn (Globe) key, and on every arrow-key event.
    static let function: UInt64 = 0x800000
}
