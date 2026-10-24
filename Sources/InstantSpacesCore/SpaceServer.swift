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
    /// The macOS keyboard shortcuts that are switched on.
    func enabledSystemShortcuts() -> [SystemShortcut]
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

    public func enabledSystemShortcuts() -> [SystemShortcut] {
        SLBCopyEnabledSymbolicHotKeys().compactMap { entry in
            guard let id = entry["id"]?.int32Value, let keyCode = entry["keyCode"]?.intValue,
                  let flags = entry["flags"]?.uint64Value else { return nil }
            return SystemShortcut(id: id, keyCode: keyCode, flags: flags)
        }
    }
}
