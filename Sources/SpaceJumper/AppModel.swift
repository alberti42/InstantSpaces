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
        static let animationDuration = "animationDurationMilliseconds"
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

    /// How long a switch slides, in milliseconds; 0 switches at once. For the
    /// shortcuts and swipes.
    @Published var animationMilliseconds: Int {
        didSet {
            UserDefaults.standard.set(animationMilliseconds, forKey: Key.animationDuration)
            switcher?.animationDuration = Double(animationMilliseconds) / 1000
        }
    }

    private let switcher: SpaceSwitcher?
    private let hotKeys = HotKeyCenter()
    private let gestureTap = GestureTap()
    private var accessTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Key.modifierPrefix: ModifierPrefix.default.rawValue,
                                     Key.arrowKeys: true, Key.desktopKeys: true, Key.swipes: true,
                                     Key.wrapsAround: false, Key.animationDuration: 0])
        modifierPrefix = ModifierPrefix(rawValue: defaults.string(forKey: Key.modifierPrefix) ?? "") ?? .default
        arrowKeysEnabled = defaults.bool(forKey: Key.arrowKeys)
        desktopKeysEnabled = defaults.bool(forKey: Key.desktopKeys)
        swipesEnabled = defaults.bool(forKey: Key.swipes)
        wrapsAround = defaults.bool(forKey: Key.wrapsAround)
        animationMilliseconds = defaults.integer(forKey: Key.animationDuration)

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
            MainActor.assumeIsolated { self?.refresh() }
        })
        // macOS shortcuts can be switched on or off in System Settings at any time.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshClashes()
                self?.refreshMacOSSettings()
            }
        }
    }

    /// The shortcuts in use, as the Settings window lists them.
    var enabledBindings: [HotKeyBinding] {
        HotKeyBinding.enabled(prefix: modifierPrefix, arrowKeys: arrowKeysEnabled, desktopKeys: desktopKeysEnabled)
    }

    /// What the menu shows to point to the Settings window, if anything.
    var attentionMessage: String? {
        if swipesNeedAccess { return "Swipes need Accessibility access; see Settings." }
        if !clashes.isEmpty || !hotKeyFailures.isEmpty { return "Some shortcuts conflict; see Settings." }
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
            rearrangesSpaces: value("mru-spaces", "com.apple.dock") as? Bool)
        if settings != macOSSettings { macOSSettings = settings }
    }

    func openTrackpadSettings() {
        openSystemSettings("com.apple.Trackpad-Settings.extension")
    }

    func openMissionControlSettings() {
        openSystemSettings("com.apple.Desktop-Settings.extension")
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
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
