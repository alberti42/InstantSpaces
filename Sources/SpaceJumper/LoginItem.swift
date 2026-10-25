import Foundation
import ServiceManagement

/// Open at Login through the embedded helper app
/// (`Contents/Library/LoginItems/SpaceJumperLoginHelper.app`).
///
/// The registration state lives in the system, not in user defaults: the user can
/// switch the item off in System Settings > General > Login Items & Extensions.
enum LoginItem {
    static let helperIdentifier = "io.alberti42.SpaceJumper.LoginHelper"

    static var service: SMAppService { .loginItem(identifier: helperIdentifier) }

    static var status: SMAppService.Status { service.status }

    static var isEnabled: Bool { status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status != .enabled { try service.register() }
        } else if status == .enabled || status == .requiresApproval {
            try service.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
