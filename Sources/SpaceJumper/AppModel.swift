import AppKit
import Combine
import SpaceJumperCore

/// State behind the menu and the Settings window: the current desktop, the
/// shortcut settings and the login item. Owns the switcher and the hotkeys.
@MainActor
final class AppModel: ObservableObject {
    private enum Key {
        static let modifierPrefix = "modifierPrefix"
        static let arrowKeys = "arrowKeysEnabled"
        static let desktopKeys = "desktopKeysEnabled"
        static let swipes = "swipesEnabled"
        static let wrapsAround = "wrapsAround"
        static let switchesOnActivation = "switchesOnActivation"
        static let animationDuration = "animationDurationMilliseconds"
        static let menuBarFrame = "menuBarFrame"
        static let menuBarFrameShape = "menuBarFrameShape"
        /// Set once SpaceJumper has shown macOS's Accessibility dialog by itself.
        static let accessibilityRequested = "accessibilityRequested"
    }

    /// Menu-bar text: the desktop number, or "F" on a full-screen Space.
    @Published private(set) var menuBarTitle = "–"
    @Published private(set) var statusLine = ""
    /// Bindings that a switched-on macOS shortcut also uses.
    @Published private(set) var clashes: [ShortcutClash] = []
    /// Bindings that `RegisterEventHotKey` refused, usually because another app holds them.
    @Published private(set) var hotKeyFailures: [String] = []
    @Published private(set) var loadError: String?
    @Published private(set) var opensAtLogin = LoginItem.isEnabled
    /// Swipes are switched on but the app lacks Accessibility permission.
    @Published private(set) var swipesNeedAccess = false
    /// The macOS settings the Settings window reports.
    @Published private(set) var macOSSettings = MacOSSettings()

    @Published var modifierPrefix: ModifierPrefix {
        didSet { UserDefaults.standard.set(modifierPrefix.rawValue, forKey: Key.modifierPrefix); registerHotKeys() }
    }
    @Published var arrowKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(arrowKeysEnabled, forKey: Key.arrowKeys); registerHotKeys() }
    }
    @Published var desktopKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(desktopKeysEnabled, forKey: Key.desktopKeys); registerHotKeys() }
    }
    /// Intercept trackpad swipes between Spaces and switch without animation.
    @Published var swipesEnabled: Bool {
        didSet { UserDefaults.standard.set(swipesEnabled, forKey: Key.swipes); updateGestureTap() }
    }
    /// Moving past the last Space goes to the first, and back; for the arrow
    /// keys and swipes.
    @Published var wrapsAround: Bool {
        didSet { UserDefaults.standard.set(wrapsAround, forKey: Key.wrapsAround); switcher?.wrapsAround = wrapsAround }
    }

    /// Switch to a Space with a window of an app when the app is activated
    /// (⌘Tab, the Dock). Acts only while macOS's own option is off; off by
    /// default.
    @Published var switchesOnActivation: Bool {
        didSet { UserDefaults.standard.set(switchesOnActivation, forKey: Key.switchesOnActivation) }
    }

    /// How long a switch slides, in milliseconds; 0 switches at once. For the
    /// shortcuts and swipes.
    @Published var animationMilliseconds: Int {
        didSet {
            UserDefaults.standard.set(animationMilliseconds, forKey: Key.animationDuration)
            switcher?.animationDuration = Double(animationMilliseconds) / 1000
        }
    }

    /// The frame around the desktop number in the menu bar.
    @Published var menuBarFrame: MenuBarFrame {
        didSet { UserDefaults.standard.set(menuBarFrame.rawValue, forKey: Key.menuBarFrame) }
    }
    @Published var menuBarFrameShape: MenuBarFrameShape {
        didSet { UserDefaults.standard.set(menuBarFrameShape.rawValue, forKey: Key.menuBarFrameShape) }
    }

    private let switcher: SpaceSwitcher?
    private let hotKeys = HotKeyCenter()
    private let gestureTap = GestureTap()
    private var accessTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    /// The app SpaceJumper switched to after its activation. It is activated
    /// again if WindowServer makes another app frontmost during that switch.
    private var followedApp: NSRunningApplication?
    /// Tells activations that come with a Space change from the user's.
    private var spaceChanges = SpaceChangeTracker(current: [])
    /// The app that was active before the latest activation.
    private var frontApp = NSWorkspace.shared.frontmostApplication

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Key.modifierPrefix: ModifierPrefix.default.rawValue,
                                     Key.arrowKeys: true, Key.desktopKeys: true, Key.swipes: true,
                                     Key.wrapsAround: false, Key.switchesOnActivation: false,
                                     Key.animationDuration: 0])
        modifierPrefix = ModifierPrefix(rawValue: defaults.string(forKey: Key.modifierPrefix) ?? "") ?? .default
        arrowKeysEnabled = defaults.bool(forKey: Key.arrowKeys)
        desktopKeysEnabled = defaults.bool(forKey: Key.desktopKeys)
        swipesEnabled = defaults.bool(forKey: Key.swipes)
        wrapsAround = defaults.bool(forKey: Key.wrapsAround)
        switchesOnActivation = defaults.bool(forKey: Key.switchesOnActivation)
        animationMilliseconds = defaults.integer(forKey: Key.animationDuration)
        menuBarFrame = MenuBarFrame(rawValue: defaults.string(forKey: Key.menuBarFrame) ?? "") ?? .none
        menuBarFrameShape = MenuBarFrameShape(rawValue: defaults.string(forKey: Key.menuBarFrameShape) ?? "") ?? .roundedRectangle

        do {
            switcher = try SpaceSwitcher()
            switcher?.wrapsAround = wrapsAround
            switcher?.animationDuration = Double(animationMilliseconds) / 1000
        } catch {
            switcher = nil
            loadError = "\(error)"
        }

        registerHotKeys()
        refresh()
        gestureTap.onSwitch = { [weak self] direction in
            guard let self, let switcher = self.switcher else { return }
            log.info("swipe \(direction.rawValue, privacy: .public)")
            switcher.move(direction)
            self.refresh()
        }
        updateGestureTap()
        refreshMacOSSettings()

        // Also posted when another tool, or the Dock, changes the Space.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            log.info("activeSpaceDidChange")
            MainActor.assumeIsolated {
                guard let self else { return }
                self.spaceChanges.spaceDidChange(to: self.windowServerCurrentSpaces(), at: Date())
                // The followed app belongs to this Space change only; it must
                // not be activated again during a later one.
                if let followed = self.followedApp {
                    DispatchQueue.main.asyncAfter(deadline: .now() + SpaceChangeTracker.grace) {
                        MainActor.assumeIsolated {
                            if self.followedApp == followed { self.followedApp = nil }
                        }
                    }
                }
                self.refresh()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.applicationDidActivate(app) }
        })
        // Reduce motion can be switched on or off in System Settings at any time.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMacOSSettings() }
        })
        // macOS shortcuts can be switched on or off in System Settings at any time.
        spaceChanges = SpaceChangeTracker(current: windowServerCurrentSpaces())
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // In case an announcement of a Space change was missed.
                if let self { self.spaceChanges.resynchronize(self.windowServerCurrentSpaces()) }
                self?.refreshClashes()
                self?.refreshMacOSSettings()
            }
        }
    }

    /// Whether SpaceJumper switches when an app is activated: the setting is
    /// on and macOS's own switch is off, so that only one of them switches.
    var switchesOnActivationEffectively: Bool {
        switchesOnActivation && !macOSSettings.switchesOnActivateEffectively
    }

    /// Switches to a Space with a window of the activated app, as macOS does
    /// with its option on. A hidden app is left to the Dock: when the app is
    /// unhidden on another Space, the Dock switches by itself, with its slide,
    /// even with the option off, and its trigger (WindowServer notification
    /// 1415) can come before the activation reaches SpaceJumper (macOS 27.0.1).
    private func applicationDidActivate(_ app: NSRunningApplication?) {
        let previous = frontApp
        frontApp = app
        guard let app, app.processIdentifier != getpid(), let switcher else { return }
        let name = app.localizedName ?? "pid \(app.processIdentifier)"
        // WindowServer brings an app of the new Space to the front when the
        // Space changes (see SpaceChangeTracker). Following it could switch
        // away from the Space just reached; after a switch on activation it
        // would also take the focus from the app the user chose.
        if spaceChanges.isChanging(current: windowServerCurrentSpaces(), at: Date()) {
            if let followed = followedApp, followed != app {
                log.info("activate \(name, privacy: .public) during the Space change; activating \(followed.localizedName ?? "?", privacy: .public) again")
                followedApp = nil
                followed.activate()
            } else {
                log.info("activate \(name, privacy: .public) during the Space change; not followed")
            }
            return
        }
        followedApp = nil
        // When the active app is hidden or quits, macOS activates another
        // app and does not change the Space. The activation arrives 10–16 ms
        // before the hide or quit is announced, but the previous app already
        // reports itself hidden, or its process is gone (macOS 27.0.1).
        if let previous, previous != app,
           previous.isHidden || previous.isTerminated || kill(previous.processIdentifier, 0) != 0 {
            log.info("activate \(name, privacy: .public) after \(previous.localizedName ?? "?", privacy: .public) was hidden or quit; not followed")
            return
        }
        refreshMacOSSettings()
        guard switchesOnActivationEffectively else { return }
        if app.isHidden {
            log.info("activate \(name, privacy: .public): hidden, left to the Dock")
            return
        }
        log.info("activate \(name, privacy: .public)")
        follow(app, switcher)
    }

    private func follow(_ app: NSRunningApplication, _ switcher: SpaceSwitcher) {
        guard switcher.followActivation(ofProcess: app.processIdentifier) != nil else { return }
        followedApp = app
        refresh()
    }

    /// The current Space of every display as WindowServer reports it, without
    /// the switcher's record of a switch in progress.
    private func windowServerCurrentSpaces() -> Set<UInt64> {
        Set(switcher?.displays().map(\.current) ?? [])
    }

    /// The shortcuts in use, as the Settings window lists them.
    var enabledBindings: [HotKeyBinding] {
        HotKeyBinding.enabled(prefix: modifierPrefix, arrowKeys: arrowKeysEnabled, desktopKeys: desktopKeysEnabled)
    }

    /// What the menu shows to point to the Settings window, if anything.
    var attentionMessage: String? {
        if swipesNeedAccess { return "Swipes need Accessibility access; see Settings." }
        if !clashes.isEmpty || !hotKeyFailures.isEmpty { return "Some shortcuts conflict; see Settings." }
        if macOSSettings.switchOnActivateNeeded(spaceJumperSwitches: switchesOnActivation) == false {
            return "⌘Tab needs a macOS option turned off; see Settings."
        }
        return nil
    }

    func requestAccessibilityPermission() {
        GestureTap.requestAccessibilityPermission()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            NSLog("SpaceJumper: could not change the login item: \(error.localizedDescription)")
        }
        opensAtLogin = LoginItem.isEnabled
        if LoginItem.status == .requiresApproval { LoginItem.openSystemSettings() }
    }

    /// Reads the trackpad and Mission Control preferences again; System
    /// Settings can change them at any time.
    func refreshMacOSSettings() {
        func value(_ key: String, _ domain: String) -> CFPropertyList? {
            CFPreferencesAppSynchronize(domain as CFString)
            return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
        }
        let trackpad = "com.apple.AppleMultitouchTrackpad"
        let settings = MacOSSettings(
            threeFingerHorizontalSwipe: value("TrackpadThreeFingerHorizSwipeGesture", trackpad) as? Int,
            fourFingerHorizontalSwipe: value("TrackpadFourFingerHorizSwipeGesture", trackpad) as? Int,
            rearrangesSpaces: value("mru-spaces", "com.apple.dock") as? Bool,
            switchesOnActivate: value("AppleSpacesSwitchOnActivate", kCFPreferencesAnyApplication as String) as? Bool,
            reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        switcher?.transition = settings.transition
        if settings != macOSSettings { macOSSettings = settings }
    }

    /// Sets macOS's "When switching to an application, switch to a Space with
    /// open windows for the application". The Dock reads the new value at
    /// the next activation, without a restart (macOS 27.0.1).
    func setMacOSSwitchesOnActivate(_ on: Bool) {
        CFPreferencesSetValue("AppleSpacesSwitchOnActivate" as CFString, on as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        log.info("AppleSpacesSwitchOnActivate set to \(on, privacy: .public)")
        refreshMacOSSettings()
    }

    func openTrackpadSettings() {
        openSystemSettings("com.apple.Trackpad-Settings.extension")
    }

    /// Accessibility → Motion, where Reduce motion is on macOS 27.0.1 (checked:
    /// `?Motion` opens it; `?Display` opens Display, which no longer has it).
    func openReduceMotionSettings() {
        openSystemSettings("com.apple.Accessibility-Settings.extension?Motion")
    }

    func openMissionControlSettings() {
        openSystemSettings("com.apple.Desktop-Settings.extension")
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The values of Copy Diagnostics… that the model knows; the Mac's details
    /// and the recent log are added by `DiagnosticsCopier`.
    func diagnostics() -> Diagnostics {
        var d = Diagnostics()
        d.accessibilityGranted = GestureTap.hasAccessibilityPermission
        d.skyLightError = loadError
        d.swipeTapRunning = gestureTap.isRunning
        d.displays = switcher?.displays() ?? []
        d.activeDisplay = switcher?.activeDisplay()?.identifier
        let duration = animationMilliseconds == 0 ? "off"
            : "\(animationMilliseconds) ms, \(macOSSettings.reducesMotion ? "cross-fade (Reduce motion on)" : "slide")"
        d.settings = [
            .init("Modifier keys", modifierPrefix.symbols),
            .init("Move between Spaces", arrowKeysEnabled ? "on" : "off"),
            .init("Go to a desktop", desktopKeysEnabled ? "on" : "off"),
            .init("Trackpad swipes", swipesEnabled ? "on" : "off"),
            .init("Wrap around", wrapsAround ? "on" : "off"),
            .init("Transition duration", duration),
            .init("Switch instantly with ⌘Tab", switchesOnActivation ? "on" : "off"),
            .init("Menu-bar frame", "\(menuBarFrame.title), \(menuBarFrameShape.title)"),
            .init("Open at login", opensAtLogin ? "on" : "off"),
        ]
        d.macOSSettings = [
            .init("Swipe between full-screen applications", macOSSettings.swipeSetting ?? "not set"),
            .init("Reduce motion", macOSSettings.reducesMotion ? "on" : "off"),
            .init("Switch to a Space with open windows (⌘Tab)", macOSSettings.switchesOnActivateEffectively ? "on" : "off"),
            .init("Automatically rearrange Spaces", macOSSettings.rearrangesSpacesEffectively ? "on" : "off"),
        ]
        d.shortcuts = enabledBindings.map(\.name)
        d.clashes = clashes.map(\.description)
        d.hotKeyFailures = hotKeyFailures
        return d
    }

    func openKeyboardShortcutsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts or stops the gesture tap to match the setting and the
    /// permission. Without permission it shows macOS's Accessibility dialog
    /// once, then checks every 2 s until the user grants it.
    private func updateGestureTap() {
        guard swipesEnabled, switcher != nil else {
            gestureTap.stop()
            stopWaitingForAccess()
            swipesNeedAccess = false
            return
        }
        if GestureTap.hasAccessibilityPermission, gestureTap.start() {
            stopWaitingForAccess()
            swipesNeedAccess = false
            return
        }
        swipesNeedAccess = true
        if !UserDefaults.standard.bool(forKey: Key.accessibilityRequested) {
            UserDefaults.standard.set(true, forKey: Key.accessibilityRequested)
            GestureTap.requestAccessibilityPermission()
        }
        if accessTimer == nil {
            accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, GestureTap.hasAccessibilityPermission else { return }
                    self.updateGestureTap()
                }
            }
        }
    }

    private func stopWaitingForAccess() {
        accessTimer?.invalidate()
        accessTimer = nil
    }

    private func registerHotKeys() {
        hotKeys.unregisterAll()
        guard let switcher else { return }
        var failures: [HotKeyCenter.Failure] = []

        for binding in enabledBindings {
            if let failure = hotKeys.register(name: binding.name, keyCode: binding.keyCode, modifiers: binding.modifiers, action: { [weak self] in
                log.info("hotkey \(binding.name, privacy: .public)")
                switch binding.action {
                case .move(let direction): switcher.move(direction)
                case .desktop(let number): switcher.goToDesktop(number)
                }
                self?.refresh()
            }) { failures.append(failure) }
        }
        hotKeyFailures = failures.map { "\($0.name) is taken by another app (error \($0.status))" }
        refreshClashes()
    }

    /// Reads the current Space. Right after a switch WindowServer can still
    /// report the old one, so the switcher's own record is used.
    private func refresh() {
        refreshClashes()
        let status: SpaceStatus
        if let switcher, let display = switcher.activeDisplay() {
            status = .make(current: switcher.currentSpace(of: display), spaces: display.spaces)
        } else {
            status = .unavailable(loadError ?? "No Spaces found.")
        }
        menuBarTitle = status.title
        statusLine = status.line
    }

    private func refreshClashes() {
        let found = switcher?.clashes(with: enabledBindings) ?? []
        if found != clashes { clashes = found }
    }
}
