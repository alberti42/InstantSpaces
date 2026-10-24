import AppKit
import Carbon.HIToolbox
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

        if arrowKeysEnabled {
            for (keyCode, direction, name) in [(kVK_LeftArrow, Direction.left, "⌃←"), (kVK_RightArrow, .right, "⌃→")] {
                if let failure = hotKeys.register(name: name, keyCode: keyCode, modifiers: controlKey, action: { [weak self] in
                    log.info("hotkey \(name, privacy: .public)")
                    switcher.move(direction)
                    self?.refresh()
                }) { failures.append(failure) }
            }
        }
        if desktopKeysEnabled {
            for (index, keyCode) in digitKeyCodes.enumerated() {
                let number = index + 1
                if let failure = hotKeys.register(name: "⌃⌘\(number)", keyCode: keyCode, modifiers: controlKey | cmdKey, action: { [weak self] in
                    log.info("hotkey ⌃⌘\(number, privacy: .public)")
                    switcher.goToDesktop(number)
                    self?.refresh()
                }) { failures.append(failure) }
            }
        }
        hotKeyFailures = failures.map { "\($0.name) is taken (error \($0.status))" }
    }

    /// Reads the current Space. Right after a switch WindowServer can still
    /// report the old one, so the switcher's own record is used.
    private func refresh() {
        refreshSystemShortcuts()
        guard let switcher, let display = switcher.activeDisplay() else {
            menuBarTitle = "–"
            statusLine = loadError ?? "No Spaces found."
            return
        }
        let current = switcher.currentSpace(of: display)
        let desktops = display.spaces.filter(\.isDesktop).count
        if let number = SpaceNavigator.desktopNumber(of: current, in: display.spaces) {
            menuBarTitle = "\(number)"
            statusLine = "Desktop \(number) of \(desktops)"
        } else {
            menuBarTitle = "F"
            statusLine = "Full-screen Space"
        }
    }

    private func refreshSystemShortcuts() {
        systemShortcutsOn = switcher.map { switcher in
            SystemHotKey.allCases.contains { switcher.isSystemHotKeyEnabled($0) }
        } ?? false
    }
}
