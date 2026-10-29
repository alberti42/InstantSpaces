import AppKit
import os

/// Changes the hidden Dock's preferences in `com.apple.dock`. Auto-hide goes
/// through HIServices' private `CoreDockSetAutoHideEnabled`, as System
/// Settings does, and the Dock follows at once. The Dock reads
/// `autohide-delay`, `digduration-duration` and `autohide-time-modifier` only
/// when it starts (`DockBarMouseEventHandler initWithConnection:` and the
/// `DockBar` setup, macOS 27.0.1), so it is restarted after they change.
enum DockPreferences {
    static let autohideDelay = "autohide-delay"
    static let digDuration = "digduration-duration"
    static let animationModifier = "autohide-time-modifier"

    private static let domain = "com.apple.dock" as CFString
    private static let log = Logger(subsystem: "io.alberti42.SpaceJumper", category: "dock")

    private typealias SetAutoHideEnabled = @convention(c) (DarwinBoolean) -> Void

    private static let setAutoHideEnabled: SetAutoHideEnabled? = {
        let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        guard let handle = dlopen(path, RTLD_NOW),
              let symbol = dlsym(handle, "CoreDockSetAutoHideEnabled") else { return nil }
        return unsafeBitCast(symbol, to: SetAutoHideEnabled.self)
    }()

    /// Reads a key of `com.apple.dock`; nil when it is not set.
    static func value(_ key: String) -> CFPropertyList? {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain)
    }

    static func setAutohides(_ on: Bool) {
        guard let setAutoHideEnabled else {
            log.error("CoreDockSetAutoHideEnabled not found")
            return
        }
        setAutoHideEnabled(DarwinBoolean(on))
        log.info("Dock autohide set to \(on, privacy: .public)")
    }

    /// Sets the keys to the numbers given; nil deletes a key, so that the Dock
    /// uses its own value. The caller restarts the Dock.
    static func set(_ values: [String: Double?]) {
        for (key, number) in values {
            CFPreferencesSetAppValue(key as CFString, number.map { $0 as CFNumber }, domain)
            log.info("Dock \(key, privacy: .public) set to \(number.map { "\($0)" } ?? "default", privacy: .public)")
        }
        CFPreferencesAppSynchronize(domain)
    }

    /// Quits the Dock as `killall Dock` does; launchd starts it again, and it
    /// reads its preferences.
    static func restartDock() {
        for dock in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock") {
            kill(dock.processIdentifier, SIGTERM)
        }
        log.info("Dock restarted")
    }
}
