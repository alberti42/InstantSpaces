import Testing
@testable import SpaceJumperCore

@Suite struct MenuBarRevealTests {
    private let bar = 30.0

    @Test func hidingChoices() {
        #expect(MenuBarHiding.always.hidesOnDesktop && MenuBarHiding.always.hidesInFullScreen)
        #expect(MenuBarHiding.onDesktopOnly.hidesOnDesktop && !MenuBarHiding.onDesktopOnly.hidesInFullScreen)
        #expect(!MenuBarHiding.inFullScreenOnly.hidesOnDesktop && MenuBarHiding.inFullScreenOnly.hidesInFullScreen)
        #expect(!MenuBarHiding.never.hidesOnDesktop && !MenuBarHiding.never.hidesInFullScreen)
        for hiding in MenuBarHiding.allCases {
            #expect(MenuBarHiding(hidesOnDesktop: hiding.hidesOnDesktop, hidesInFullScreen: hiding.hidesInFullScreen) == hiding)
        }
    }

    @Test func showsAtTheTouchAndHidesAfterThePointerLeaves() {
        var reveal = MenuBarReveal()
        #expect(reveal.pointer(display: 2, fromTop: 200, barHeight: bar, menuBarShown: false, at: 0) == [])
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 1) == [.show(display: 2)])
        // In the menu bar: it stays, however long.
        #expect(reveal.pointer(display: 2, fromTop: 10, barHeight: bar, menuBarShown: true, at: 5) == [])
        // Below it: it hides after the grace period.
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 6) == [])
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 6.2) == [])
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 6.31) == [.hide(display: 2)])
        #expect(reveal.shownDisplay == nil)
    }

    @Test func returningToTheBarCancelsTheHide() {
        var reveal = MenuBarReveal()
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0)
        _ = reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 1)
        _ = reveal.pointer(display: 2, fromTop: 10, barHeight: bar, menuBarShown: true, at: 1.2)
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 1.4) == [])
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 1.65) == [])
        #expect(reveal.pointer(display: 2, fromTop: 100, barHeight: bar, menuBarShown: true, at: 1.71) == [.hide(display: 2)])
    }

    @Test func waitsWithThePointerAtTheEdge() {
        var reveal = MenuBarReveal(wait: 0.2)
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0) == [])
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0.1) == [])
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0.2) == [.show(display: 2)])
    }

    @Test func leavingTheEdgeRestartsTheWait() {
        var reveal = MenuBarReveal(wait: 0.2)
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0)
        _ = reveal.pointer(display: 2, fromTop: 5, barHeight: bar, menuBarShown: false, at: 0.1)
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0.15) == [])
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0.3) == [])
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0.36) == [.show(display: 2)])
    }

    @Test func aMenuBarAlreadyShownIsLeftAlone() {
        var reveal = MenuBarReveal()
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: true, at: 0) == [])
        #expect(reveal.shownDisplay == nil)
    }

    /// The override's own 0x524 comes within 10 ms; macOS's own reveal later.
    @Test func handsOverWhenMacOSRevealsItself() {
        var reveal = MenuBarReveal()
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 10)
        #expect(reveal.menuBarRevealed(at: 10.004) == nil)
        #expect(reveal.shownDisplay == 2)
        #expect(reveal.menuBarRevealed(at: 10.42) == .hide(display: 2))
        #expect(reveal.shownDisplay == nil)
        // The pointer is still at the top, and macOS shows the menu bar now.
        #expect(reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: true, at: 10.5) == [])
    }

    @Test func movingToAnotherDisplayHidesTheFirst() {
        var reveal = MenuBarReveal()
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0)
        #expect(reveal.pointer(display: 3, fromTop: 0, barHeight: bar, menuBarShown: false, at: 1)
                == [.hide(display: 2), .show(display: 3)])
    }

    @Test func stopAndClearedOverride() {
        var reveal = MenuBarReveal()
        #expect(reveal.stop() == nil)
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 0)
        #expect(reveal.stop() == .hide(display: 2))
        _ = reveal.pointer(display: 2, fromTop: 0, barHeight: bar, menuBarShown: false, at: 1)
        reveal.overrideCleared()
        #expect(reveal.shownDisplay == nil)
        #expect(reveal.stop() == nil)
    }
}
