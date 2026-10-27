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
    /// The width in points of the display with this identifier.
    func displayWidth(_ display: String) -> Double
    /// The normal windows (layer 0) of a process, front to back, with their
    /// Spaces and whether they are shown or hidden with their app.
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
        let states = SLBCopyWindowStates(ids.map { NSNumber(value: $0) })
        return ids.map { id in
            let state = states[NSNumber(value: id)]
            return AppWindow(id: id, spaces: SLBCopySpacesForWindow(id).map(\.uint64Value),
                             isShown: (state?["attributes"]?.uint64Value ?? 0) & 0x2 != 0,
                             isHiddenWithApp: (state?["tags"]?.uint64Value ?? 0) & 0x80_0000_0000 != 0)
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
}
