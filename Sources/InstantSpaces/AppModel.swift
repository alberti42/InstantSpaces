import AppKit
import Combine
import InstantSpacesCore

/// State behind the menu: the current desktop, the shortcut settings and the
/// login item. Owns the switcher and the hotkeys.
@MainActor
final class AppModel: ObservableObject {
    private enum Key {
        static let arrowKeys = "arrowKeysEnabled"
        static let desktopKeys = "desktopKeysEnabled"
    }

    /// Menu-bar text: the desktop number, or "F" on a full-screen Space.
    @Published private(set) var menuBarTitle = "–"
    @Published private(set) var statusLine = ""
    /// Whether macOS's own Ctrl-arrow shortcut, which switches with the slide, is on.
    @Published private(set) var systemShortcutsOn = false
    @Published private(set) var hotKeyFailures: [String] = []
    @Published private(set) var loadError: String?
    @Published private(set) var opensAtLogin = LoginItem.isEnabled

    @Published var arrowKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(arrowKeysEnabled, forKey: Key.arrowKeys); registerHotKeys() }
    }
    @Published var desktopKeysEnabled: Bool {
        didSet { UserDefaults.standard.set(desktopKeysEnabled, forKey: Key.desktopKeys); registerHotKeys() }
    }

    private let switcher: SpaceSwitcher?
    private let hotKeys = HotKeyCenter()
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

    init() {
        UserDefaults.standard.register(defaults: [Key.arrowKeys: true, Key.desktopKeys: true])
        arrowKeysEnabled = UserDefaults.standard.bool(forKey: Key.arrowKeys)
        desktopKeysEnabled = UserDefaults.standard.bool(forKey: Key.desktopKeys)

        do {
            switcher = try SpaceSwitcher()
        } catch {
            switcher = nil
            loadError = "\(error)"
        }

        registerHotKeys()
        refresh()

        // Also posted when another tool, or the Dock, changes the Space.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            log.info("activeSpaceDidChange")
            MainActor.assumeIsolated { self?.refresh() }
        })
        // The system shortcut can be switched on or off in System Settings at any time.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSystemShortcuts() }
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            NSLog("InstantSpaces: could not change the login item: \(error.localizedDescription)")
        }
        opensAtLogin = LoginItem.isEnabled
        if LoginItem.status == .requiresApproval { LoginItem.openSystemSettings() }
    }

    func openKeyboardShortcutsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func registerHotKeys() {
        hotKeys.unregisterAll()
        guard let switcher else { return }
        var failures: [HotKeyCenter.Failure] = []

        for binding in HotKeyBinding.enabled(arrowKeys: arrowKeysEnabled, desktopKeys: desktopKeysEnabled) {
            if let failure = hotKeys.register(name: binding.name, keyCode: binding.keyCode, modifiers: binding.modifiers, action: { [weak self] in
                log.info("hotkey \(binding.name, privacy: .public)")
                switch binding.action {
                case .move(let direction): switcher.move(direction)
                case .desktop(let number): switcher.goToDesktop(number)
                }
                self?.refresh()
            }) { failures.append(failure) }
        }
        hotKeyFailures = failures.map { "\($0.name) is taken (error \($0.status))" }
    }

    /// Reads the current Space. Right after a switch WindowServer can still
    /// report the old one, so the switcher's own record is used.
    private func refresh() {
        refreshSystemShortcuts()
        let status: SpaceStatus
        if let switcher, let display = switcher.activeDisplay() {
            status = .make(current: switcher.currentSpace(of: display), spaces: display.spaces)
        } else {
            status = .unavailable(loadError ?? "No Spaces found.")
        }
        menuBarTitle = status.title
        statusLine = status.line
    }

    private func refreshSystemShortcuts() {
        systemShortcutsOn = switcher.map { switcher in
            SystemHotKey.allCases.contains { switcher.isSystemHotKeyEnabled($0) }
        } ?? false
    }
}
