import Carbon.HIToolbox
import Testing
@testable import InstantSpacesCore

// Values as SLSGetSymbolicHotKeyValue reported them on macOS 27.0.1.
private let moveLeftASpace = SystemShortcut(id: 79, keyCode: kVK_LeftArrow, flags: 0x840000)
private let moveRightASpace = SystemShortcut(id: 81, keyCode: kVK_RightArrow, flags: 0x840000)
private let shiftControlLeft = SystemShortcut(id: 80, keyCode: kVK_LeftArrow, flags: 0x860000)
private let switchToDesktop1 = SystemShortcut(id: 118, keyCode: kVK_ANSI_1, flags: 0x40000)

@Suite struct SystemShortcutTests {
    @Test func controlArrowClashesWithMoveASpace() {
        let clashes = ShortcutClash.find(HotKeyBinding.arrowKeys(.control), in: [moveLeftASpace, moveRightASpace])
        #expect(clashes.map(\.binding.name) == ["⌃←", "⌃→"])
        #expect(clashes.first?.description == "⌃← is also used by macOS (Move left a space)")
    }

    /// Arrow-key events always carry the fn flag; macOS stores ⌃← with it.
    @Test func fnFlagIsIgnoredForArrows() {
        let binding = HotKeyBinding.arrowKeys(.control)[0]
        #expect(moveLeftASpace.clashes(with: binding))
        #expect(SystemShortcut(id: 1, keyCode: kVK_LeftArrow, flags: 0x40000).clashes(with: binding))
    }

    /// For other keys a shortcut that needs fn (Globe) is a different shortcut.
    @Test func fnFlagCountsForDigits() {
        let binding = HotKeyBinding.desktopKeys(.control)[0]
        #expect(switchToDesktop1.clashes(with: binding))
        #expect(!SystemShortcut(id: 2, keyCode: kVK_ANSI_1, flags: 0x840000).clashes(with: binding))
    }

    @Test func extraModifiersDoNotClash() {
        #expect(!shiftControlLeft.clashes(with: HotKeyBinding.arrowKeys(.control)[0]))
        #expect(!moveLeftASpace.clashes(with: HotKeyBinding.arrowKeys(.controlOption)[0]))
    }

    @Test func otherKeysDoNotClash() {
        #expect(!moveLeftASpace.clashes(with: HotKeyBinding.arrowKeys(.control)[1]))
    }

    @Test func names() {
        #expect(moveLeftASpace.name == "Move left a space")
        #expect(moveRightASpace.name == "Move right a space")
        #expect(switchToDesktop1.name == "Switch to Desktop 1")
        #expect(SystemShortcut(id: 126, keyCode: kVK_ANSI_9, flags: 0x40000).name == "Switch to Desktop 9")
        #expect(SystemShortcut(id: 240, keyCode: kVK_LeftArrow, flags: 0x840000).name == "macOS shortcut 240")
    }
}
