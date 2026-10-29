import CoreGraphics
import Foundation
import SkyLightBridge

/// What `SpaceSwitcher` needs from WindowServer. `SkyLightServer` is the real
/// one; tests pass a fake that records the calls.
public protocol SpaceServer: AnyObject {
    /// The raw result of `SLSCopyManagedDisplaySpaces`.
    func managedDisplaySpaces() -> [[String: Any]]
    /// The identifier of the display with the active menu bar.
    func activeMenuBarDisplay() -> String?
    func showSpaces(_ spaces: [UInt64])
    func setCurrentSpace(_ space: UInt64, display: String)
    func hideSpaces(_ spaces: [UInt64])
    /// Draws `space` shifted `x` points to the right of its place; 0 puts it back.
    func setSpaceOffset(_ space: UInt64, x: Double)
    /// Freezes the screen for a cross-fade; nil if WindowServer refused.
    func freezeScreen() -> Int32?
    /// Dissolves the frozen screen into the current one over `duration`.
    func dissolveScreen(_ freeze: Int32, duration: TimeInterval)
    /// The width in points of the display with this identifier.
    func displayWidth(_ display: String) -> Double
    /// The normal windows (layer 0) of a process, front to back, with their
    /// Spaces and whether they are shown.
    func windows(ofProcess pid: Int32) -> [AppWindow]
    /// The macOS keyboard shortcuts that are switched on, without names.
    func enabledSystemShortcuts() -> [SystemShortcut]
    /// SkyLight's internal name of a shortcut, e.g. "WindowTileLeftHalf".
    func systemShortcutName(_ id: Int32) -> String?
    /// Whether WindowServer would trigger the shortcut for a key-down event
    /// with this key code and these `CGEventFlags`.
    func eventTriggers(_ id: Int32, keyCode: Int, flags: UInt64) -> Bool
}

public struct SkyLightUnavailable: Error, CustomStringConvertible {
    public let description: String
}

/// `SpaceServer` through SkyLight: bridged window-management operations for
/// the switch, plain SkyLight functions for the queries.
public final class SkyLightServer: SpaceServer {
    public init() throws {
        var error: NSString?
        guard SLBLoad(&error) else {
            throw SkyLightUnavailable(description: (error as String?) ?? "SkyLight could not be loaded.")
        }
    }

    public func managedDisplaySpaces() -> [[String: Any]] {
        (SLBCopyManagedDisplaySpaces() as? [[String: Any]]) ?? []
    }

    public func activeMenuBarDisplay() -> String? {
        SLBActiveMenuBarDisplay()
    }

    public func showSpaces(_ spaces: [UInt64]) {
        SLBShowSpaces(spaces.map { NSNumber(value: $0) })
    }

    public func setCurrentSpace(_ space: UInt64, display: String) {
        SLBSetCurrentSpace(display, space)
    }

    public func hideSpaces(_ spaces: [UInt64]) {
        SLBHideSpaces(spaces.map { NSNumber(value: $0) })
    }

    public func setSpaceOffset(_ space: UInt64, x: Double) {
        SLBSetSpaceOffset(space, x)
    }

    public func freezeScreen() -> Int32? {
        let transition = SLBFreezeScreenForFade()
        return transition == 0 ? nil : transition
    }

    /// How long the frozen screen waits before it dissolves, so that the
    /// asynchronous bridged operations have completed the switch underneath.
    static let dissolveDelay: TimeInterval = 0.15

    public func dissolveScreen(_ freeze: Int32, duration: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dissolveDelay) {
            SLBDissolveScreen(freeze, duration)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                SLBReleaseTransition(freeze)
            }
        }
    }

    public func displayWidth(_ display: String) -> Double {
        SLBDisplayWidth(display)
    }

    public func windows(ofProcess pid: Int32) -> [AppWindow] {
        // In front-to-back order. IDs and owners need no Screen Recording permission.
        let info = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let ids = info.compactMap { window -> UInt32? in
            guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            return (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        }
        let attributes = SLBCopyWindowAttributes(ids.map { NSNumber(value: $0) })
        return ids.map { id in
            AppWindow(id: id, spaces: SLBCopySpacesForWindow(id).map(\.uint64Value),
                      isShown: (attributes[NSNumber(value: id)]?.uint64Value ?? 0) & 0x2 != 0)
        }
    }

    public func enabledSystemShortcuts() -> [SystemShortcut] {
        SLBCopyEnabledSymbolicHotKeys().compactMap { entry in
            guard let id = entry["id"]?.int32Value, let keyCode = entry["keyCode"]?.intValue,
                  let flags = entry["flags"]?.uint64Value else { return nil }
            return SystemShortcut(id: id, keyCode: keyCode, flags: flags)
        }
    }

    public func systemShortcutName(_ id: Int32) -> String? {
        SLBSymbolicHotKeyName(id)
    }

    public func eventTriggers(_ id: Int32, keyCode: Int, flags: UInt64) -> Bool {
        SLBEventMatchesSymbolicHotKey(UInt16(keyCode), flags, id)
    }

    /// Tells WindowServer whether to switch Spaces when an app is activated,
    /// as System Settings does after changing `AppleSpacesSwitchOnActivate`;
    /// the preference alone takes effect only when the Dock restarts. Needs a
    /// `SkyLightServer` to have loaded SkyLight.
    public static func setSwitchesOnAppActivation(_ on: Bool) -> Bool {
        SLBSetSwitchesOnAppActivation(on)
    }

    // The menu bar (see `MenuBarReveal`). Like the call above, these need a
    // `SkyLightServer` to have loaded SkyLight.

    @discardableResult
    public static func setMenuBarOverride(display: UInt32, _ on: Bool) -> Bool {
        SLBSetMenuBarOverride(display, on)
    }

    public static func menuBarOverride(display: UInt32) -> Bool {
        SLBMenuBarOverride(display)
    }

    /// 0 hidden to 1 shown, for the current Space.
    public static func menuBarReveal() -> Double {
        SLBMenuBarReveal()
    }

    public static func currentSpace() -> UInt64 {
        SLBActiveSpace()
    }

    public static func observeMenuBarReveals(_ handler: @escaping (UInt64) -> Void) {
        SLBObserveMenuBarReveals(handler)
    }

    @discardableResult
    public static func setMenuBarAutohide(_ on: Bool) -> Bool {
        SLBSetMenuBarAutohide(on)
    }
}
