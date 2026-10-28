import Carbon.HIToolbox
import Foundation
import Testing
@testable import SpaceJumperCore

@Suite struct AppShortcutTests {
    private let mail = AppShortcut(letter: "M", bundleIdentifier: "com.freron.MailMate", name: "MailMate")
    private let music = AppShortcut(letter: "U", bundleIdentifier: "com.apple.Music", name: "Music")

    @Test func suggestsTheFirstFreeLetterOfTheName() {
        #expect(AppShortcut.suggestedLetter(for: "Mail", taken: []) == "M")
        #expect(AppShortcut.suggestedLetter(for: "Music", taken: [mail]) == "U")
        #expect(AppShortcut.suggestedLetter(for: "Mm", taken: [mail]) == "A")
        #expect(AppShortcut.suggestedLetter(for: "Ö", taken: []) == "A")
    }

    @Test func suggestsNothingWhenAllLettersAreTaken() {
        let all = AppShortcut.letters.map { AppShortcut(letter: $0, bundleIdentifier: "\($0)", name: "\($0)") }
        #expect(AppShortcut.suggestedLetter(for: "Mail", taken: all) == nil)
    }

    @Test func assigningATakenLetterSwapsTheLetters() {
        let result = AppShortcut.assign("U", to: mail.bundleIdentifier, in: [mail, music])
        #expect(result.map(\.letter) == ["U", "M"])
    }

    @Test func assigningAFreeLetterChangesOnlyThatShortcut() {
        let result = AppShortcut.assign("X", to: mail.bundleIdentifier, in: [mail, music])
        #expect(result.map(\.letter) == ["X", "U"])
    }

    @Test func survivesEncoding() throws {
        let data = try JSONEncoder().encode([mail, music])
        #expect(try JSONDecoder().decode([AppShortcut].self, from: data) == [mail, music])
    }

    @Test func bindingsUseThePrefixAndTheLayoutsKeys() {
        let keyCodes: [Character: Int] = ["M": kVK_ANSI_M]
        let bindings = HotKeyBinding.appKeys(.controlCommand, [mail, music], keyCode: { keyCodes[$0] })
        #expect(bindings == [HotKeyBinding(name: "⌃⌘M", keyCode: kVK_ANSI_M, prefix: .controlCommand,
                                           action: .app("com.freron.MailMate"))])
    }
}
