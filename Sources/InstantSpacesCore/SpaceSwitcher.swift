import Foundation
import os

public let log = Logger(subsystem: "io.alberti42.InstantSpaces", category: "switch")

/// Switches Spaces: show the new Space, make it current, hide the others.
/// WindowServer does this at once; the Dock, which draws the slide, is not involved.
public final class SpaceSwitcher {
    /// The bridged operations are asynchronous, so WindowServer can still report
    /// the old Space right after a switch. For this long after a switch, the
    /// switcher counts from the Space it switched to, so that quick repeated
    /// presses move one Space each.
    public static let pendingInterval: TimeInterval = 0.5

    private let server: SpaceServer
    private let now: () -> Date
    private var pending: (display: String, space: UInt64, time: Date)?

    /// `now` is the clock for the pending interval; tests pass their own.
    public init(server: SpaceServer, now: @escaping () -> Date = Date.init) {
        self.server = server
        self.now = now
    }

    /// A switcher that talks to WindowServer through SkyLight.
    public convenience init() throws {
        try self.init(server: SkyLightServer())
    }

    public func displays() -> [DisplaySpaces] {
        DisplaySpaces.parse(server.managedDisplaySpaces())
    }

    /// The display with the active menu bar. When displays share Spaces,
    /// SkyLight lists a single display named "Main", which is returned instead.
    public func activeDisplay() -> DisplaySpaces? {
        let all = displays()
        let active = server.activeMenuBarDisplay()
        return all.first { $0.identifier == active } ?? all.first
    }

    /// The current Space of `display`, taking a switch still in progress into account.
    public func currentSpace(of display: DisplaySpaces) -> UInt64 {
        if let pending, pending.display == display.identifier,
           now().timeIntervalSince(pending.time) < Self.pendingInterval {
            return pending.space
        }
        return display.current
    }

    /// Moves one Space left or right on the active display. Returns the Space
    /// switched to, or nil at either end.
    @discardableResult
    public func move(_ direction: Direction) -> UInt64? {
        guard let display = activeDisplay(),
              let target = SpaceNavigator.neighbour(of: currentSpace(of: display), in: display.spaces, direction: direction)
        else { return nil }
        switchTo(target, on: display)
        return target
    }

    /// Goes to user desktop `number` (1-based) on the active display.
    @discardableResult
    public func goToDesktop(_ number: Int) -> UInt64? {
        guard let display = activeDisplay(),
              let target = SpaceNavigator.desktop(number, in: display.spaces)
        else { return nil }
        switchTo(target, on: display)
        return target
    }

    /// Switches `display` to `space`. Every other Space of the display is
    /// hidden, not only the current one, so a wrong idea of the current Space
    /// cannot leave two Spaces on screen.
    public func switchTo(_ space: UInt64, on display: DisplaySpaces) {
        let current = currentSpace(of: display)
        guard space != current else { return }
        log.info("switch \(current, privacy: .public) -> \(space, privacy: .public) on \(display.identifier, privacy: .public)")
        server.showSpaces([space])
        server.setCurrentSpace(space, display: display.identifier)
        server.hideSpaces(display.spaces.map(\.id).filter { $0 != space })
        pending = (display.identifier, space, now())
    }

    /// The bindings among `bindings` that would also trigger a switched-on
    /// macOS shortcut, as WindowServer decides it. Names are looked up only for
    /// the shortcuts found.
    public func clashes(with bindings: [HotKeyBinding]) -> [ShortcutClash] {
        ShortcutClash.find(bindings, in: server.enabledSystemShortcuts()) { binding, shortcut in
            server.eventTriggers(shortcut.id, keyCode: binding.keyCode, flags: binding.keyboardEventFlags)
        }.map { clash in
            var shortcut = clash.shortcut
            shortcut.identifier = server.systemShortcutName(shortcut.id)
            return ShortcutClash(binding: clash.binding, shortcut: shortcut)
        }
    }
}
