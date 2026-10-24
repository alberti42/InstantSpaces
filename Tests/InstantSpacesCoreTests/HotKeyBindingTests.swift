import Carbon.HIToolbox
import Testing
@testable import InstantSpacesCore

@Suite struct HotKeyBindingTests {
    @Test func arrowKeysUseControlOnly() {
        #expect(HotKeyBinding.arrowKeys.map(\.name) == ["⌃←", "⌃→"])
        #expect(HotKeyBinding.arrowKeys.map(\.keyCode) == [kVK_LeftArrow, kVK_RightArrow])
        #expect(HotKeyBinding.arrowKeys.allSatisfy { $0.modifiers == controlKey })
        #expect(HotKeyBinding.arrowKeys.map(\.action) == [.move(.left), .move(.right)])
    }

    @Test func desktopKeysCoverOneToNine() {
        let bindings = HotKeyBinding.desktopKeys
        #expect(bindings.map(\.name) == (1...9).map { "⌃⌘\($0)" })
        #expect(bindings.map(\.action) == (1...9).map { .desktop($0) })
        #expect(bindings.allSatisfy { $0.modifiers == controlKey | cmdKey })
    }

    /// ANSI key codes are not in key order: 5 is 23 and 6 is 22, for example.
    @Test func desktopKeysUseTheDigitKeyCodes() {
        #expect(HotKeyBinding.desktopKeys.map(\.keyCode)
            == [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9])
    }

    @Test func noTwoBindingsShareAKey() {
        let all = HotKeyBinding.enabled(arrowKeys: true, desktopKeys: true)
        let keys = Set(all.map { "\($0.keyCode)-\($0.modifiers)" })
        #expect(keys.count == all.count)
    }

    @Test func enabledFollowsTheSettings() {
        #expect(HotKeyBinding.enabled(arrowKeys: true, desktopKeys: true).count == 11)
        #expect(HotKeyBinding.enabled(arrowKeys: true, desktopKeys: false) == HotKeyBinding.arrowKeys)
        #expect(HotKeyBinding.enabled(arrowKeys: false, desktopKeys: true) == HotKeyBinding.desktopKeys)
        #expect(HotKeyBinding.enabled(arrowKeys: false, desktopKeys: false).isEmpty)
    }
}
