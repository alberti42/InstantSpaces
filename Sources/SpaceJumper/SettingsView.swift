import SpaceJumperCore
import SwiftUI

/// The Settings window, opened from the menu with Settings… (⌘,).
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralPane(model: model) }
            Tab("Shortcuts", systemImage: "keyboard") { ShortcutsPane(model: model) }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refreshMacOSSettings() }
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
            }

            Section {
                Toggle(isOn: $model.swipesEnabled) {
                    Text("Switch instantly on trackpad swipes")
                    Text("Swiping left or right between Spaces")
                }
                LabeledContent {
                    HStack {
                        if let setting = model.macOSSettings.swipeSetting {
                            Text(setting)
                        }
                        Button("Change…") { model.openTrackpadSettings() }
                    }
                } label: {
                    Text("Swipe set in macOS")
                    Text("SpaceJumper reacts to the swipe macOS uses between Spaces: Trackpad → More Gestures → Swipe between full-screen applications.")
                }
                if model.swipesNeedAccess {
                    Label("SpaceJumper needs Accessibility access to intercept swipes.", systemImage: "exclamationmark.triangle")
                    HStack {
                        Button("Open Accessibility Settings…") { model.openAccessibilitySettings() }
                        Button("Ask Again") { model.requestAccessibilityPermission() }
                    }
                }
            } header: {
                Text("Trackpad")
            } footer: {
                Text("Turn it off to keep macOS's swipe with its animation; SpaceJumper then needs no Accessibility access.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Wrap around from the last Space to the first", isOn: $model.wrapsAround)
            } footer: {
                Text("For \(prefix)← \(prefix)→ and trackpad swipes. macOS stops at the first and last Space.")
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
                        LabeledContent {
                            Button("Open Keyboard Shortcuts…") { model.openKeyboardShortcutsSettings() }
                        } label: {
                            Text("Turn the macOS shortcut off")
                            Text("When macOS uses the same keys, both macOS and SpaceJumper react. Turn the macOS shortcut off in System Settings → Keyboard → Keyboard Shortcuts, or choose other modifier keys.")
                        }
                    }
                } header: {
                    Text("Conflicts")
                }
            }
        }
        .formStyle(.grouped)
        // The window grows to fit the pane instead of scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel
    @Bindable private var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        // No `step`: it draws a tick per step. The value is rounded
                        // to 10 ms instead.
                        Slider(value: Binding(
                            get: { Double(model.animationMilliseconds) },
                            set: { model.animationMilliseconds = Int(($0 / 10).rounded()) * 10 }),
                               in: 0...500)
                            .frame(width: 160)
                        Text(model.animationMilliseconds == 0 ? "Off" : "\(model.animationMilliseconds) ms")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                } label: {
                    Text("Slide animation")
                    Text("How long a switch slides, for the shortcuts and swipes. Off switches at once.")
                }
            }

            Section {
                LabeledContent {
                    HStack {
                        Text(model.macOSSettings.rearrangesSpacesEffectively ? "On" : "Off")
                        Button("Change…") { model.openMissionControlSettings() }
                    }
                } label: {
                    Label {
                        Text("Automatically rearrange Spaces based on most recent use")
                        Text(model.macOSSettings.rearrangeExplanation)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            } header: {
                Text("Mission Control")
            }
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
                     ? "SpaceJumper checks once a week."
                     : "Updates are only available in SpaceJumper.app.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!updater.isAvailable)
        }
        .formStyle(.grouped)
        // The window grows to fit the pane instead of scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}
