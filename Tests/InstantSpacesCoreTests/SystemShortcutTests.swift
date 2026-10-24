import Carbon.HIToolbox
import Testing
@testable import InstantSpacesCore

// Values as SkyLight reported them on macOS 27.0.1.
private let tileLeftHalf = SystemShortcut(id: 240, keyCode: kVK_LeftArrow, flags: 0x840000, identifier: "WindowTileLeftHalf")
private let splitViewMakeLeft = SystemShortcut(id: 199, keyCode: kVK_LeftArrow, flags: 0x840000, identifier: "SplitViewMakeLeft")
private let switchToDesktop1 = SystemShortcut(id: 118, keyCode: kVK_ANSI_1, flags: 0x40000, identifier: "Workspaces1")

@Suite struct SystemShortcutTests {
    @Test func knownNamesUseTheSystemSettingsLabel() {
        #expect(tileLeftHalf.name == "“Tile Left Half” (Windows)")
        #expect(switchToDesktop1.name == "“Switch to Desktop 1” (Mission Control)")
        #expect(SystemShortcut(id: 127, keyCode: 0, flags: 0, identifier: "Workspaces10").name == "“Switch to Desktop 10” (Mission Control)")
        #expect(SystemShortcut(id: 79, keyCode: 0, flags: 0, identifier: "WorkspacesLeft").name == "“Move left a Space” (Mission Control)")
    }

    @Test func unknownNamesShowNumberAndIdentifier() {
        #expect(splitViewMakeLeft.name == "macOS shortcut 199 (SplitViewMakeLeft)")
        #expect(SystemShortcut(id: 300, keyCode: 0, flags: 0).name == "macOS shortcut 300")
        // Numbered keypad variants are not "Switch to Desktop N".
        #expect(SystemShortcut(id: 134, keyCode: 0, flags: 0, identifier: "WorkspacesNumPad1").label == nil)
    }

    @Test func clashDescription() {
        let clash = ShortcutClash(binding: HotKeyBinding.arrowKeys(.control)[0], shortcut: tileLeftHalf)
        #expect(clash.description == "⌃← also triggers “Tile Left Half” (Windows)")
    }

    @Test func findAsksOnlyAboutShortcutsOnTheSameKey() {
        var asked: [Int32] = []
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control), in: [tileLeftHalf, switchToDesktop1]) { _, shortcut in
            asked.append(shortcut.id)
            return true
        }
        #expect(asked == [240])
        #expect(clashes.map(\.binding.name) == ["⌃←"])
    }

    @Test func findKeepsOnlyWhatTheMatcherConfirms() {
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control), in: [tileLeftHalf, splitViewMakeLeft]) { _, shortcut in
            shortcut.id == 240
        }
        #expect(clashes.map(\.shortcut.id) == [240])
    }
}
