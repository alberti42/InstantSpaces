import Foundation

/// The values of the diagnostics report, gathered by the app (Copy
/// Diagnostics… in the menu) and formatted by `report`. Plain text the user
/// reads and pastes into a GitHub issue; nothing is sent anywhere.
public struct Diagnostics: Sendable {
    /// One event tap from `CGGetEventTapList`, as the report lists it.
    public struct EventTap: Equatable, Sendable {
        public let name: String
        public let pid: Int32
        public let isThisApp: Bool
        /// It can stop an event from reaching the apps after it; otherwise it only listens.
        public let canBlock: Bool
        /// "HID", "session" or "app".
        public let level: String
        public let enabled: Bool

        public init(name: String, pid: Int32, isThisApp: Bool, canBlock: Bool, level: String, enabled: Bool = true) {
            self.name = name
            self.pid = pid
            self.isThisApp = isThisApp
            self.canBlock = canBlock
            self.level = level
            self.enabled = enabled
        }
    }

    public struct Setting: Equatable, Sendable {
        public let name: String
        public let value: String

        public init(_ name: String, _ value: String) {
            self.name = name
            self.value = value
        }
    }

    /// SpaceJumper's version and build, e.g. "0.3.1 (build 6)".
    public var version = "?"
    /// `ProcessInfo.operatingSystemVersionString`.
    public var macOS = "?"
    /// `hw.model`, e.g. "Mac15,9".
    public var macModel = "?"
    /// The output of `csrutil status`.
    public var systemIntegrityProtection = "?"
    public var accessibilityGranted = false
    /// Nil when SkyLight loaded; otherwise why not.
    public var skyLightError: String?
    public var swipeTapRunning = false
    public var displays: [DisplaySpaces] = []
    /// The identifier of the display with the active menu bar.
    public var activeDisplay: String?
    public var settings: [Setting] = []
    public var macOSSettings: [Setting] = []
    /// The names of the registered shortcuts, e.g. "⌃→".
    public var shortcuts: [String] = []
    public var clashes: [String] = []
    public var hotKeyFailures: [String] = []
    /// Taps on trackpad gesture or Dock control events (types 29 and 30), in
    /// the order macOS lists them; nil if the list was not available. The
    /// report sorts them by delivery order (`deliveryOrder`).
    public var swipeTaps: [EventTap]? = []
    /// Taps on key presses, in the order macOS lists them.
    public var keyboardTaps: [EventTap]? = []
    /// Recent log messages, oldest first, each with its time.
    public var recentActivity: [String] = []

    public init() {}

    /// The report as plain text.
    public func report() -> String {
        var r = """
        # SpaceJumper — diagnostics
        # Plain text. Read it and delete any line you prefer not to share before posting.

        ## Versions
        SpaceJumper : \(version)
        macOS       : \(macOS)
        Mac model   : \(macModel)
        System Integrity Protection : \(systemIntegrityProtection)

        ## Permissions and state
        Accessibility (trackpad swipes) : \(accessibilityGranted ? "granted" : "NOT granted")
        SkyLight                        : \(skyLightError.map { "NOT loaded: \($0)" } ?? "loaded")
        Swipe event tap                 : \(swipeTapRunning ? "running" : "not running")

        ## Displays and Spaces
        # In Mission Control order; * marks the current Space. "active" is the
        # display with the menu bar, where the shortcuts act.

        """
        if displays.isEmpty { r += "(none)\n" }
        for display in displays {
            r += "display \(display.identifier)\(display.identifier == activeDisplay ? " (active)" : "")\n"
            for space in display.spaces {
                let name = SpaceNavigator.desktopNumber(of: space.id, in: display.spaces).map { "desktop \($0)" }
                    ?? "full screen"
                r += "  \(space.id == display.current ? "*" : " ") \(space.id)\t\(name)\n"
            }
        }
        r += "\n## SpaceJumper settings\n" + Self.aligned(settings)
        r += "\n## macOS settings\n" + Self.aligned(macOSSettings)
        r += "\n## Shortcuts\n"
        r += "Registered          : \(shortcuts.isEmpty ? "none" : shortcuts.joined(separator: "  "))\n"
        r += "Clash with macOS    : \(clashes.isEmpty ? "none" : "")\n"
        r += clashes.map { "  \($0)\n" }.joined()
        r += "Taken by other apps : \(hotKeyFailures.isEmpty ? "none" : "")\n"
        r += hotKeyFailures.map { "  \($0)\n" }.joined()
        r += """

        ## Apps that intercept trackpad swipes
        # Each app below sees the trackpad's swipe events; the first one
        # receives them first. "can block" = it can stop an event from reaching
        # the apps after it; "listens" = it only watches. An app that can block,
        # listed before SpaceJumper, may take the swipes away.

        """
        r += Self.list(swipeTaps.map(Self.deliveryOrder))
        r += """

        ## Apps that intercept the keyboard
        # Each app below sees key presses; the first one receives them first.
        # One that can block may keep SpaceJumper's shortcuts from working.

        """
        r += Self.list(keyboardTaps.map(Self.deliveryOrder))
        r += """

        ## Recent activity
        # The last messages SpaceJumper logged: switches, hotkeys, swipes, ⌘Tab.

        """
        r += recentActivity.isEmpty ? "(none)\n" : recentActivity.map { $0 + "\n" }.joined()
        return r
    }

    /// Taps in the order an event reaches them: an event passes the HID-level
    /// taps, then the session-level ones, then the app-level ones. Within a
    /// level the order of `CGGetEventTapList` is kept; across levels that list
    /// is not in delivery order (it listed a session tap before a HID tap on
    /// macOS 27.0.1).
    static func deliveryOrder(_ taps: [EventTap]) -> [EventTap] {
        let rank = ["HID": 0, "session": 1]
        return taps.enumerated()
            .sorted { (rank[$0.element.level] ?? 2, $0.offset) < (rank[$1.element.level] ?? 2, $1.offset) }
            .map(\.element)
    }

    /// The numbered lines of a list of taps.
    static func list(_ taps: [EventTap]?) -> String {
        guard let taps else { return "(the list of event taps is not available)\n" }
        if taps.isEmpty { return "(none)\n" }
        return taps.enumerated().map { index, tap in
            "\(index + 1). \(tap.name)\(tap.isThisApp ? " (this app)" : "") (pid \(tap.pid)): "
                + "\(tap.canBlock ? "can block" : "listens")\(tap.enabled ? "" : " (disabled)")\n"
        }.joined()
    }

    /// One "name : value" line per setting, the colons aligned.
    static func aligned(_ settings: [Setting]) -> String {
        let width = settings.map(\.name.count).max() ?? 0
        return settings.map { $0.name.padding(toLength: width, withPad: " ", startingAt: 0) + " : " + $0.value + "\n" }
            .joined()
    }
}
