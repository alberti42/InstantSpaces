import SwiftUI

struct InstantSpacesApp: App {
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
        Image(nsImage: MenuBarTitleImage.make(model.menuBarTitle))
            .accessibilityLabel(model.statusLine)
            #if DEBUG
            // `--show-settings` opens the Settings window at launch, for
            // screenshots and checks without clicking the menu.
            .task {
                guard CommandLine.arguments.contains("--show-settings") else { return }
                NSApp.activate()
                openSettings()
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
        }
        .keyboardShortcut(",")
        UpdateItem(updater: Updater.shared)
        Divider()

        Button("Quit InstantSpaces") { NSApp.terminate(nil) }
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
