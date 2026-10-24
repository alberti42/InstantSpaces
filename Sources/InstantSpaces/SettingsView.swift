import InstantSpacesCore
import SwiftUI

/// The Settings window, opened from the menu with Settings… (⌘,).
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            Tab("Shortcuts", systemImage: "keyboard") { ShortcutsPane(model: model) }
            Tab("General", systemImage: "gearshape") { GeneralPane(model: model) }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Shortcuts

private struct ShortcutsPane: View {
    @ObservedObject var model: AppModel

    private var prefix: String { model.modifierPrefix.symbols }

    var body: some View {
        Form {
            Section {
                Picker("Modifier keys", selection: $model.modifierPrefix) {
                    ForEach(ModifierPrefix.allCases, id: \.self) { prefix in
                        Text(prefix.symbols).tag(prefix)
                    }
                }
                Toggle(isOn: $model.arrowKeysEnabled) {
                    Text("Move between Spaces")
                    Text("\(prefix)←  \(prefix)→")
                }
                Toggle(isOn: $model.desktopKeysEnabled) {
                    Text("Go to a desktop")
                    Text("\(prefix)1 … \(prefix)9")
                }
            } footer: {
                Text("All shortcuts use the same modifier keys. ⌃ matches macOS's own Mission Control shortcuts.")
                    .foregroundStyle(.secondary)
            }

            if !model.clashes.isEmpty || !model.hotKeyFailures.isEmpty {
                Section {
                    ForEach(model.clashes, id: \.description) { clash in
                        Label(clash.description, systemImage: "exclamationmark.triangle")
                    }
                    ForEach(model.hotKeyFailures, id: \.self) { failure in
                        Label(failure, systemImage: "exclamationmark.triangle")
                    }
                    if !model.clashes.isEmpty {
                        Button("Open Keyboard Shortcuts…") { model.openKeyboardShortcutsSettings() }
                    }
                } header: {
                    Text("Conflicts")
                } footer: {
                    Text("When macOS uses the same keys, both macOS and InstantSpaces react. Turn the macOS shortcut off in System Settings → Keyboard → Keyboard Shortcuts, or choose other modifier keys.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel
    @Bindable private var updater = Updater.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }))
            }
            Section {
                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                Button("Check Now") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            } header: {
                Text("Updates")
            } footer: {
                Text(updater.isAvailable
                     ? "InstantSpaces checks once a week."
                     : "Updates are only available in InstantSpaces.app.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!updater.isAvailable)
        }
        .formStyle(.grouped)
    }
}
