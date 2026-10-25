import Foundation
import SpaceJumperCore

/// SpaceJumper was called InstantSpaces up to version 0.1.1, with the bundle
/// identifier `io.alberti42.InstantSpaces`. On the first launch under the new
/// identifier, the settings are copied over once.
enum SettingsMigration {
    private static let oldDomain = "io.alberti42.InstantSpaces"
    private static let doneKey = "settingsMigratedFromInstantSpaces"
    /// Not `accessibilityRequested`: the new app has to ask for Accessibility again.
    private static let keys = ["modifierPrefix", "arrowKeysEnabled", "desktopKeysEnabled", "swipesEnabled",
                               "wrapsAround", "animationDurationMilliseconds", "SUEnableAutomaticChecks"]

    /// Runs before anything reads the settings, Sparkle included.
    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        guard let old = defaults.persistentDomain(forName: oldDomain) else { return }
        var copied: [String] = []
        for key in keys {
            guard let value = old[key], defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
            copied.append(key)
        }
        if !copied.isEmpty {
            log.info("copied InstantSpaces settings: \(copied.joined(separator: ", "), privacy: .public)")
        }
    }
}
