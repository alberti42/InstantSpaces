/// One normal window (layer 0) of an app, as `SpaceServer.windows(ofProcess:)`
/// reports it.
public struct AppWindow: Equatable, Sendable {
    public let id: UInt32
    /// `SLSCopySpacesForWindows`; empty for some ordered-out windows.
    public let spaces: [UInt64]
    /// Ordered in on its Space (window attribute 0x2). False for a minimized
    /// window, a window of a hidden app and an ordered-out window, which can
    /// still report a Space.
    public let isShown: Bool
    /// Hidden with its app (window tag 0x8000000000); it is shown again when
    /// the app is activated. A window minimized before the app was hidden
    /// does not count.
    public let isHiddenWithApp: Bool

    public init(id: UInt32, spaces: [UInt64], isShown: Bool, isHiddenWithApp: Bool = false) {
        self.id = id
        self.spaces = spaces
        self.isShown = isShown
        self.isHiddenWithApp = isHiddenWithApp
    }

    /// On screen once its app is active: shown, or hidden with the app.
    public var appearsOnActivation: Bool { isShown || isHiddenWithApp }
}

/// Where to switch when an app is activated, as macOS does with "When
/// switching to an application, switch to a Space with open windows for the
/// application". Pure functions, so they can be tested.
public enum ActivationTarget {
    /// The Space of the app's frontmost window that appears on activation
    /// (shown, or hidden with the app) and the display that has it, or nil
    /// when such a window is already on a current Space or there is none. `windows` is in front-to-back order; `currentSpaces`
    /// holds the current Space of every display. When an app whose only
    /// window is minimized is activated, macOS does not switch either
    /// (checked on macOS 27.0.1).
    public static func find(windows: [AppWindow], displays: [DisplaySpaces],
                            currentSpaces: Set<UInt64>) -> (space: UInt64, display: DisplaySpaces)? {
        let shown = windows.filter { $0.appearsOnActivation && !$0.spaces.isEmpty }
        if shown.contains(where: { !currentSpaces.isDisjoint(with: $0.spaces) }) { return nil }
        for window in shown {
            for space in window.spaces {
                if let display = displays.first(where: { $0.spaces.contains { $0.id == space } }) {
                    return (space, display)
                }
            }
        }
        return nil
    }
}
