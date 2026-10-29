import Foundation

/// macOS's "Automatically hide and show the menu bar" (System Settings → Menu
/// Bar), stored as `com.apple.controlcenter AutoHideMenuBarOption`. The pane
/// applies a choice as two settings: hiding on desktops
/// (`CGSSetMenuBarAutohideEnabled`, `_HIHideMenuBar`) and hiding in
/// full-screen apps (`AppleMenuBarVisibleInFullscreen`, inverted).
public enum MenuBarHiding: Int, CaseIterable, Sendable {
    case always = 0
    case onDesktopOnly = 1
    case inFullScreenOnly = 2
    case never = 3

    /// System Settings' labels.
    public var title: String {
        switch self {
        case .always: "Always"
        case .onDesktopOnly: "On Desktop Only"
        case .inFullScreenOnly: "In Full Screen Only"
        case .never: "Never"
        }
    }

    public var hidesOnDesktop: Bool { self == .always || self == .onDesktopOnly }
    public var hidesInFullScreen: Bool { self == .always || self == .inFullScreenOnly }

    /// The choice from its two settings, when `AutoHideMenuBarOption` is not set.
    public init(hidesOnDesktop: Bool, hidesInFullScreen: Bool) {
        switch (hidesOnDesktop, hidesInFullScreen) {
        case (true, true): self = .always
        case (true, false): self = .onDesktopOnly
        case (false, true): self = .inFullScreenOnly
        case (false, false): self = .never
        }
    }
}

/// Shows the hidden menu bar sooner than macOS, and leaves it to macOS once
/// macOS shows it too. SpaceJumper shows the menu bar by turning WindowServer's
/// override on for the display (`SLSSetMenuBarVisibilityOverrideOnDisplay`);
/// while the override is on, the menu bar stays shown. The override goes off
///  - when macOS reveals the menu bar itself (WindowServer notification 0x524
///    for the current Space, later than the override's own, which come within
///    10 ms). The menu bar then stays, and macOS hides it when it decides to;
///  - or when the pointer has been below the menu bar for `hideDelay`: the
///    menu bar hides, as macOS hides it after the pointer leaves. An open menu
///    keeps it shown (macOS does that by itself).
/// macOS's own wait was 347–1181 ms on macOS 27.0.1; turning the override off
/// while it was still counting made the menu bar hide and show again.
public struct MenuBarReveal: Sendable {
    public enum Action: Equatable, Sendable {
        case show(display: UInt32)
        case hide(display: UInt32)
    }

    /// How long the pointer stays below the menu bar before it hides. 0.15 s
    /// showed no flicker (user, 2026-10-29); the default keeps a margin.
    /// Turning the override off while macOS's own wait was still counting
    /// made the menu bar hide and show again.
    public static let defaultHideDelay: TimeInterval = 0.2
    /// 0x524 within this time after the override went on are the override's own.
    public static let ownNotificationTime: TimeInterval = 0.06

    /// How long the pointer stays at the top edge before the menu bar shows.
    public var wait: TimeInterval
    /// How long the pointer stays below the menu bar before it hides.
    public var hideDelay = MenuBarReveal.defaultHideDelay
    /// The display whose override is on.
    public private(set) var shownDisplay: UInt32?
    private var shownAt: TimeInterval = 0
    /// Where and since when the pointer has been at the top edge.
    private var edge: (display: UInt32, since: TimeInterval)?
    /// When the pointer went below the menu bar while the override was on.
    private var leftAt: TimeInterval?

    public init(wait: TimeInterval = 0) {
        self.wait = wait
    }

    /// A sample of the pointer: its display, its distance from the display's
    /// top in points, the height of that display's menu bar, and whether the
    /// menu bar there is already fully shown.
    public mutating func pointer(display: UInt32, fromTop: Double, barHeight: Double,
                                 menuBarShown: Bool, at now: TimeInterval) -> [Action] {
        var actions: [Action] = []
        if let shown = shownDisplay, shown != display {
            actions.append(hideOverride())
        }
        if fromTop < 1 {
            leftAt = nil
            guard shownDisplay == nil else { return actions }
            // macOS shows it already (another reveal, or a menu bar that does
            // not hide on this Space).
            guard !menuBarShown else { edge = nil; return actions }
            if edge?.display != display { edge = (display, now) }
            if let edge, now - edge.since >= wait {
                shownDisplay = display
                shownAt = now
                self.edge = nil
                actions.append(.show(display: display))
            }
            return actions
        }
        edge = nil
        guard let shown = shownDisplay else { return actions }
        if fromTop <= barHeight {
            leftAt = nil
            return actions
        }
        let left = leftAt ?? now
        leftAt = left
        if now - left >= hideDelay {
            actions.append(.hide(display: shown))
            shownDisplay = nil
            leftAt = nil
        }
        return actions
    }

    /// WindowServer announced a reveal of the current Space (0x524). Later
    /// than the override's own, it is macOS's: the override can go off
    /// without changing the screen.
    public mutating func menuBarRevealed(at now: TimeInterval) -> Action? {
        guard shownDisplay != nil, now - shownAt > Self.ownNotificationTime else { return nil }
        return hideOverride()
    }

    /// WindowServer turned the override off by itself (seen after Space changes).
    public mutating func overrideCleared() {
        shownDisplay = nil
        leftAt = nil
    }

    /// Turns the override off, when the setting is switched off or the app quits.
    public mutating func stop() -> Action? {
        edge = nil
        return shownDisplay == nil ? nil : hideOverride()
    }

    private mutating func hideOverride() -> Action {
        let display = shownDisplay!
        shownDisplay = nil
        leftAt = nil
        return .hide(display: display)
    }
}
