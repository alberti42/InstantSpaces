import Foundation
import os
import SkyLightBridge

public let log = Logger(subsystem: "io.alberti42.InstantSpaces", category: "switch")

public struct SkyLightUnavailable: Error, CustomStringConvertible {
    public let description: String
}

/// Switches Spaces with SkyLight's bridged operations: show the new Space, make
/// it current, hide the others. WindowServer does this at once; the Dock, which
/// draws the slide, is not involved.
public final class SpaceSwitcher {
    /// The bridged operations are asynchronous, so WindowServer can still report
    /// the old Space right after a switch. For this long after a switch, the
    /// switcher counts from the Space it switched to, so that quick repeated
    /// presses move one Space each.
    private static let pendingInterval: TimeInterval = 0.5

    private var pending: (display: String, space: UInt64, time: Date)?

    public init() throws {
        var error: NSString?
        guard SLBLoad(&error) else {
            throw SkyLightUnavailable(description: (error as String?) ?? "SkyLight could not be loaded.")
        }
    }

    public func displays() -> [DisplaySpaces] {
        DisplaySpaces.parse((SLBCopyManagedDisplaySpaces() as? [[String: Any]]) ?? [])
    }

    /// The display with the active menu bar. When displays share Spaces,
    /// SkyLight lists a single display named "Main", which is returned instead.
    public func activeDisplay() -> DisplaySpaces? {
        let all = displays()
        let active = SLBActiveMenuBarDisplay()
        return all.first { $0.identifier == active } ?? all.first
    }

    /// The current Space of `display`, taking a switch still in progress into account.
    public func currentSpace(of display: DisplaySpaces) -> UInt64 {
        if let pending, pending.display == display.identifier,
           Date().timeIntervalSince(pending.time) < Self.pendingInterval {
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
        let others = display.spaces.map(\.id).filter { $0 != space }
        SLBShowSpaces([NSNumber(value: space)])
        SLBSetCurrentSpace(display.identifier, space)
        SLBHideSpaces(others.map { NSNumber(value: $0) })
        pending = (display.identifier, space, Date())
    }

    /// Whether a system symbolic hotkey is enabled; see `SystemHotKey`.
    public func isSystemHotKeyEnabled(_ hotKey: SystemHotKey) -> Bool {
        SLBSymbolicHotKeyEnabled(hotKey.rawValue)
    }
}

/// System shortcuts that switch Spaces with the Dock's animation.
public enum SystemHotKey: Int32, CaseIterable, Sendable {
    case moveLeftASpace = 79
    case moveRightASpace = 81
}
