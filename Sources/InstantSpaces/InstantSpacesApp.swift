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
            Text(model.menuBarTitle)
                .monospacedDigit()
                .accessibilityLabel(model.statusLine)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let loadError = model.loadError {
            Text("Cannot switch Spaces: \(loadError)")
        } else {
            Text(model.statusLine)
        }
        Divider()

        Toggle("⌃← ⌃→ Move between Spaces", isOn: $model.arrowKeysEnabled)
        Toggle("⌃⌘1–9 Go to a desktop", isOn: $model.desktopKeysEnabled)
        if model.arrowKeysEnabled && model.systemShortcutsOn {
            Text("macOS also switches on ⌃← ⌃→, with the animation.")
            Button("Turn Off in Keyboard Shortcuts…") { model.openKeyboardShortcutsSettings() }
        }
        ForEach(model.hotKeyFailures, id: \.self) { Text($0) }
        Divider()

        Toggle("Open at Login", isOn: Binding(
            get: { model.opensAtLogin },
            set: { model.setOpensAtLogin($0) }))
        Divider()

        UpdateItems(updater: Updater.shared)
        Divider()

        Button("Quit InstantSpaces") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Sparkle's menu items (`Updater`). An unbundled build has no updater.
private struct UpdateItems: View {
    @Bindable var updater: Updater

    var body: some View {
        if updater.isAvailable {
            Button(updater.pendingVersion.map { "Update to \($0)…" } ?? "Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            Toggle("Check for Updates Automatically", isOn: $updater.automaticallyChecks)
        } else {
            Text("Updates are only available in InstantSpaces.app.")
        }
    }
}
