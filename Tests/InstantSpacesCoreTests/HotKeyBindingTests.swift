import Carbon.HIToolbox
import Testing
@testable import InstantSpacesCore

@Suite struct HotKeyBindingTests {
    @Test func defaultPrefixIsControl() {
        #expect(ModifierPrefix.default == .control)
    }

    @Test(arguments: ModifierPrefix.allCases)
    func arrowsAndDigitsShareThePrefix(_ prefix: ModifierPrefix) {
        let all = HotKeyBinding.enabled(prefix: prefix, arrowKeys: true, desktopKeys: true)
        #expect(all.count == 11)
        #expect(all.allSatisfy { $0.modifiers == prefix.carbonModifiers && $0.name.hasPrefix(prefix.symbols) })
    }

    @Test func arrowKeys() {
        let bindings = HotKeyBinding.arrowKeys(.controlOption)
        #expect(bindings.map(\.name) == ["⌃⌥←", "⌃⌥→"])
        #expect(bindings.map(\.keyCode) == [kVK_LeftArrow, kVK_RightArrow])
        #expect(bindings.map(\.action) == [.move(.left), .move(.right)])
    }

    @Test func desktopKeysCoverOneToNine() {
        let bindings = HotKeyBinding.desktopKeys(.control)
        #expect(bindings.map(\.name) == (1...9).map { "⌃\($0)" })
        #expect(bindings.map(\.action) == (1...9).map { .desktop($0) })
    }

    /// ANSI key codes are not in key order: 5 is 23 and 6 is 22, for example.
    @Test func desktopKeysUseTheDigitKeyCodes() {
        #expect(HotKeyBinding.desktopKeys(.control).map(\.keyCode)
            == [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9])
    }

    @Test func enabledFollowsTheSettings() {
        #expect(HotKeyBinding.enabled(prefix: .control, arrowKeys: true, desktopKeys: false) == HotKeyBinding.arrowKeys(.control))
        #expect(HotKeyBinding.enabled(prefix: .control, arrowKeys: false, desktopKeys: true) == HotKeyBinding.desktopKeys(.control))
        #expect(HotKeyBinding.enabled(prefix: .control, arrowKeys: false, desktopKeys: false).isEmpty)
    }

    @Test func prefixesAreDistinct() {
        #expect(Set(ModifierPrefix.allCases.map(\.carbonModifiers)).count == ModifierPrefix.allCases.count)
        #expect(Set(ModifierPrefix.allCases.map(\.symbols)).count == ModifierPrefix.allCases.count)
    }

    /// The flags of a real key-down event: arrows always add fn (0x800000) and
    /// numeric pad (0x200000); digits add nothing.
    @Test func keyboardEventFlags() {
        #expect(HotKeyBinding.arrowKeys(.control)[0].keyboardEventFlags == 0xA40000)
        #expect(HotKeyBinding.arrowKeys(.controlOption)[1].keyboardEventFlags == 0xAC0000)
        #expect(HotKeyBinding.desktopKeys(.control)[0].keyboardEventFlags == 0x40000)
    }

    @Test func eventFlagsMatchTheCarbonModifiers() {
        #expect(ModifierPrefix.control.eventFlags == 0x40000)
        #expect(ModifierPrefix.controlOption.eventFlags == 0xC0000)
        #expect(ModifierPrefix.controlCommand.eventFlags == 0x140000)
        #expect(ModifierPrefix.optionCommand.eventFlags == 0x180000)
        #expect(ModifierPrefix.controlOptionCommand.eventFlags == 0x1C0000)
    }
}
