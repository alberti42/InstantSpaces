/// A command given on the command line, for testing the switch without hotkeys.
public enum Command: Equatable, Sendable {
    case list
    case move(Direction)
    case desktop(Int)
    case space(UInt64)

    public static let usage = "usage: SpaceJumper [--list | --move left|right | --desktop N | --space ID]"

    /// Flags for the menu-bar app itself rather than a command (debug builds:
    /// `--show-settings` opens the Settings window at launch).
    public static let appFlags: Set<String> = ["--show-settings"]

    public enum ParseResult: Equatable, Sendable {
        /// No command: start the menu-bar app.
        case none
        case command(Command)
        case invalid
    }

    /// Parses the arguments after the executable's path. Arguments that do not
    /// start with "--", such as the "-psn_…" that older systems pass to apps,
    /// mean no command.
    public static func parse(_ arguments: [String]) -> ParseResult {
        guard let flag = arguments.first, flag.hasPrefix("--"), !appFlags.contains(flag) else { return .none }
        let value = arguments.dropFirst().first
        switch flag {
        case "--list":
            return .command(.list)
        case "--move":
            guard let value, let direction = Direction(rawValue: value) else { return .invalid }
            return .command(.move(direction))
        case "--desktop":
            guard let value, let number = Int(value), number >= 1 else { return .invalid }
            return .command(.desktop(number))
        case "--space":
            guard let value, let space = UInt64(value) else { return .invalid }
            return .command(.space(space))
        default:
            return .invalid
        }
    }
}
