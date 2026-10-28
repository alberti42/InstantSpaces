import SpaceJumperCore
import SwiftUI

/// The Settings window, opened from the menu with Settings… (⌘,).
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralPane(model: model) }
            Tab("Spaces", systemImage: "rectangle.split.3x1") { SpacesPane(model: model) }
            Tab("Apps", systemImage: "square.grid.2x2") { AppsPane(model: model) }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refreshMacOSSettings() }
    }
}

// MARK: Spaces

private struct SpacesPane: View {
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
                    Text("Go to a Space by number")
                    Text("\(prefix)1 … \(prefix)9")
                }
                Picker(selection: $model.spaceNumbering) {
                    ForEach(SpaceNumbering.allCases, id: \.self) { numbering in
                        Text(numbering.title).tag(numbering)
                    }
                } label: {
                    Text("Numbering")
                    Text(model.spaceNumbering == .allSpaces
                         ? "Every Space by its position in Mission Control, full-screen apps included. The menu bar shows the same number."
                         : "Only desktops, as macOS's \"Switch to Desktop N\" shortcuts count them. The menu bar shows F on a full-screen Space.")
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
                    Text("Duration")
                    Text("How long a switch takes, for the shortcuts, swipes and ⌘Tab. Off switches at once.")
                }
                Toggle(isOn: $model.followsReduceMotion) {
                    Text("Cross-fade when Reduce motion is on")
                    Text("Turn it off to keep the slide while Reduce motion stays on for the rest of macOS.")
                }
                LabeledContent {
                    HStack {
                        Text(model.macOSSettings.reducesMotion ? "On" : "Off")
                        Button("Change…") { model.openReduceMotionSettings() }
                    }
                } label: {
                    Label {
                        Text("Reduce motion")
                        Text(model.macOSSettings.reduceMotionExplanation(followingReduceMotion: model.followsReduceMotion))
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            } header: {
                Text("Transition")
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

// MARK: Apps

private struct AppsPane: View {
    @ObservedObject var model: AppModel

    private var prefix: String { model.appModifierPrefix.symbols }

    var body: some View {
        Form {
            Section {
                Picker("Modifier keys", selection: $model.appModifierPrefix) {
                    ForEach(ModifierPrefix.allCases, id: \.self) { prefix in
                        Text(prefix.symbols).tag(prefix)
                    }
                }
            }
            Section {
                ForEach(model.appShortcuts) { shortcut in
                    LabeledContent {
                        HStack {
                            Picker("Letter", selection: Binding(
                                get: { shortcut.letter },
                                set: { model.setLetter($0, of: shortcut) })) {
                                ForEach(AppShortcut.letters, id: \.self) { letter in
                                    Text(prefix + String(letter)).tag(letter)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Button {
                                model.removeAppShortcut(shortcut)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove the shortcut for \(shortcut.name)")
                        }
                    } label: {
                        Label {
                            Text(shortcut.name)
                        } icon: {
                            Image(nsImage: AppIcon.of(shortcut.bundleIdentifier))
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Add App…") { model.addAppShortcut() }
                        .disabled(model.appShortcuts.count == AppShortcut.letters.count)
                }
            } header: {
                Text("Jump to an app")
            } footer: {
                Text("\(prefix) and the letter switch to the Space with the app's frontmost window, full-screen or not, and bring the app forward. An app that is not open is opened.")
                    .foregroundStyle(.secondary)
            }
            if model.appModifierPrefix == .control && !model.appShortcuts.isEmpty {
                Label("With ⌃ alone, these shortcuts take keys that text fields use, such as ⌃A and ⌃E (start and end of line). Choose other modifier keys above.",
                      systemImage: "exclamationmark.triangle")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The icon of an installed app, 16 points; a generic app icon when it is not found.
private enum AppIcon {
    static func of(_ bundleIdentifier: String) -> NSImage {
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var model: AppModel
    @Bindable private var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.switchesOnActivation) {
                    Text("Switch instantly with ⌘Tab")
                    Text("When ⌘Tab or the Dock activates an app with no window on this Space, SpaceJumper switches to a Space where it has one. macOS's option below has to be off.")
                }
                LabeledContent {
                    HStack {
                        Text(model.macOSSettings.switchesOnActivateEffectively ? "On" : "Off")
                        if let needed = model.macOSSettings.switchOnActivateNeeded(spaceJumperSwitches: model.switchesOnActivation) {
                            Button(needed ? "Turn On" : "Turn Off") { model.setMacOSSwitchesOnActivate(needed) }
                        }
                        Button("Change…") { model.openMissionControlSettings() }
                    }
                } label: {
                    Label {
                        Text("When switching to an application, switch to a Space with open windows for the application")
                        Text(model.macOSSettings.switchOnActivateExplanation(spaceJumperSwitches: model.switchesOnActivation))
                    } icon: {
                        Image(systemName: model.macOSSettings.switchOnActivateNeeded(spaceJumperSwitches: model.switchesOnActivation) == false
                              ? "exclamationmark.triangle" : "info.circle")
                    }
                }
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
            Section {
                Picker("Frame", selection: $model.menuBarFrame) {
                    ForEach(MenuBarFrame.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Shape", selection: $model.menuBarFrameShape) {
                    ForEach(MenuBarFrameShape.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(model.menuBarFrame == .none)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("A frame tells the desktop number apart from other numbers in the menu bar. Filled cuts the number out of the shape; a capsule around one digit is a circle.")
                    .foregroundStyle(.secondary)
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
