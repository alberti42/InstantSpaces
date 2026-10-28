import SwiftUI

struct SpaceJumperApp: App {
    @StateObject private var model = AppModel()

    init() {
        Updater.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }
}

/// The desktop number in the menu bar.
private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: MenuBarTitleImage.make(model.menuBarTitle, frame: model.menuBarFrame, shape: model.menuBarFrameShape))
            .accessibilityLabel(model.statusLine)
            #if DEBUG
            // `--show-settings` opens the Settings window at launch, for
            // screenshots and checks without clicking the menu.
            .task {
                guard CommandLine.arguments.contains("--show-settings") else { return }
                NSApp.activate()
                openSettings()
                SettingsWindow.bringToFront()
            }
            #endif
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let loadError = model.loadError {
            Text("Cannot switch Spaces: \(loadError)")
        } else {
            Text(model.statusLine)
        }
        if let message = model.attentionMessage {
            Text(message)
        }
        Divider()

        // An app without a Dock icon opens its windows behind the active app
        // unless it activates itself first.
        Button("Settings…") {
            NSApp.activate()
            openSettings()
            SettingsWindow.bringToFront()
        }
        .keyboardShortcut(",")
        Button("About SpaceJumper") { AboutPanel.show() }
        UpdateItem(updater: Updater.shared)
        Divider()

        Button("Quit SpaceJumper") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Sparkle's menu item (`Updater`). An unbundled build has no updater.
private struct UpdateItem: View {
    var updater: Updater

    var body: some View {
        if updater.isAvailable {
            Button(updater.pendingVersion.map { "Update to \($0)…" } ?? "Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

/// Since macOS 14 `NSApp.activate()` is a request that macOS can decline while
/// another app is active; the Settings window then opened behind it (seen
/// with Ghostty). Ordering the window itself to the front works regardless.
@MainActor
enum SettingsWindow {
    static func bringToFront() {
        // `openSettings` creates the window on a later pass of the run loop.
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: {
                $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            }) else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

/// macOS's standard About panel: name, version and build from Info.plist,
/// the copyright line (`NSHumanReadableCopyright`), and a credit with the
/// README's description and a link to the repository. Brought to the front
/// like the Settings window (`SettingsWindow`).
@MainActor
enum AboutPanel {
    private static let repository = URL(string: "https://github.com/alberti42/SpaceJumper")!

    static func show() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
        // The panel is a plain NSPanel (macOS 27.0.1); the app's other windows
        // are status-bar windows and the SwiftUI Settings window.
        DispatchQueue.main.async {
            guard let panel = NSApp.windows.first(where: { type(of: $0) == NSPanel.self && $0.isVisible }) else { return }
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }

    private static func credits() -> NSAttributedString {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let text = NSMutableAttributedString(
            string: "A menu-bar app for macOS that switches between Spaces without the slide animation, or with a slide as long as you choose.\n\n",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: centered])
        text.append(NSAttributedString(
            string: "github.com/alberti42/SpaceJumper",
            attributes: [.font: font, .link: repository, .paragraphStyle: centered]))
        return text
    }
}
