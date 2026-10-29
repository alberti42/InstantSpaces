import AppKit
import SpaceJumperCore
import os

/// macOS's "Automatically hide and show the menu bar", read and changed as
/// System Settings → Menu Bar does it (ControlCenterSettings.appex, macOS
/// 27.0.1): `AutoHideMenuBarOption` for the choice, `_HIHideMenuBar` and
/// `CGSSetMenuBarAutohideEnabled` for desktops, `AppleMenuBarVisibleInFullscreen`
/// for full-screen apps, then two distributed notifications for the apps.
enum MenuBarPreferences {
    private static let controlCenter = "com.apple.controlcenter" as CFString
    private static let log = Logger(subsystem: "io.alberti42.SpaceJumper", category: "menubar")

    static func hiding() -> MenuBarHiding {
        CFPreferencesAppSynchronize(controlCenter)
        if let option = CFPreferencesCopyAppValue("AutoHideMenuBarOption" as CFString, controlCenter) as? Int,
           let hiding = MenuBarHiding(rawValue: option) {
            return hiding
        }
        let hidesOnDesktop = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["_HIHideMenuBar"] as? Bool ?? false
        let visibleInFullScreen = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleMenuBarVisibleInFullscreen"] as? Bool ?? false
        return MenuBarHiding(hidesOnDesktop: hidesOnDesktop, hidesInFullScreen: !visibleInFullScreen)
    }

    static func setHiding(_ hiding: MenuBarHiding) {
        CFPreferencesSetAppValue("AutoHideMenuBarOption" as CFString, hiding.rawValue as CFNumber, controlCenter)
        CFPreferencesAppSynchronize(controlCenter)
        // Each app reads these two when the notifications below arrive.
        // `CGSSetMenuBarAutohideEnabled` does not write `_HIHideMenuBar`
        // (checked); the pane writes it, as a Swift string short enough to
        // be stored in the code, so `strings` does not show it.
        CFPreferencesSetValue("_HIHideMenuBar" as CFString, hiding.hidesOnDesktop as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSetValue("AppleMenuBarVisibleInFullscreen" as CFString, !hiding.hidesInFullScreen as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let applied = SkyLightServer.setMenuBarAutohide(hiding.hidesOnDesktop)
        let center = DistributedNotificationCenter.default()
        for name in ["AppleInterfaceMenuBarHidingChangedNotification",
                     "AppleInterfaceFullScreenMenuBarVisibilityChangedNotification"] {
            center.postNotificationName(.init(name), object: nil, userInfo: nil, deliverImmediately: true)
        }
        log.info("menu bar hiding set to \(hiding.title, privacy: .public), WindowServer told: \(applied, privacy: .public)")
    }
}

/// Shows the hidden menu bar as soon as the pointer touches the top edge,
/// following `MenuBarReveal`. Samples the pointer 60 times a second while it
/// runs (`NSEvent.mouseLocation`, which needs no permission).
@MainActor
final class MenuBarRevealer {
    private var reveal = MenuBarReveal()
    private var timer: Timer?
    private let log = Logger(subsystem: "io.alberti42.SpaceJumper", category: "menubar")

    init() {
        SkyLightServer.observeMenuBarReveals { [weak self] space in
            MainActor.assumeIsolated { self?.menuBarRevealed(space: space) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    /// Starts or stops, with the wait at the top edge before the menu bar shows.
    func update(enabled: Bool, wait: TimeInterval, hideDelay: TimeInterval) {
        reveal.wait = wait
        reveal.hideDelay = hideDelay
        if enabled, timer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            log.info("menu bar reveal started")
        } else if !enabled, timer != nil {
            stop()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        if let action = reveal.stop() { perform(action) }
        log.info("menu bar reveal stopped")
    }

    private func tick() {
        if let shown = reveal.shownDisplay, !SkyLightServer.menuBarOverride(display: shown) {
            log.info("WindowServer turned the menu-bar override off on display \(shown)")
            reveal.overrideCleared()
        }
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
              let display = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return }
        // The menu bar's height: the notch's on a built-in display with one,
        // the status bar's otherwise.
        let barHeight = max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        let actions = reveal.pointer(display: display, fromTop: screen.frame.maxY - point.y, barHeight: barHeight,
                                     menuBarShown: SkyLightServer.menuBarReveal() >= 1,
                                     at: ProcessInfo.processInfo.systemUptime)
        actions.forEach(perform)
    }

    private func menuBarRevealed(space: UInt64) {
        guard space == SkyLightServer.currentSpace(),
              let action = reveal.menuBarRevealed(at: ProcessInfo.processInfo.systemUptime) else { return }
        log.debug("macOS revealed the menu bar itself")
        perform(action)
    }

    private func perform(_ action: MenuBarReveal.Action) {
        switch action {
        case .show(let display):
            SkyLightServer.setMenuBarOverride(display: display, true)
            log.debug("menu bar shown on display \(display)")
        case .hide(let display):
            SkyLightServer.setMenuBarOverride(display: display, false)
            log.debug("menu bar given back to macOS on display \(display)")
        }
    }
}
