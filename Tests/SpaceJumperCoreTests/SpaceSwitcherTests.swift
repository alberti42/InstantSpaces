import Foundation
import Testing
@testable import SpaceJumperCore

/// A `SpaceServer` that serves fixed displays and records the switch calls.
private final class FakeServer: SpaceServer {
    enum Call: Equatable {
        case show([UInt64])
        case setCurrent(UInt64, display: String)
        case hide([UInt64])
        case offset(UInt64, x: Double)
        case freeze
        case dissolve(Int32, duration: Double)
    }

    var displays: [[String: Any]]
    var activeDisplay: String?
    var shortcuts: [SystemShortcut] = []
    var names: [Int32: String] = [:]
    var appWindows: [Int32: [AppWindow]] = [:]
    /// (shortcut, key code, flags) that WindowServer would trigger.
    var triggers: Set<String> = []
    private(set) var matchQueries: [(id: Int32, keyCode: Int, flags: UInt64)] = []
    private(set) var calls: [Call] = []

    init(displays: [[String: Any]], activeDisplay: String?) {
        self.displays = displays
        self.activeDisplay = activeDisplay
    }

    func managedDisplaySpaces() -> [[String: Any]] { displays }
    func activeMenuBarDisplay() -> String? { activeDisplay }
    func showSpaces(_ spaces: [UInt64]) { calls.append(.show(spaces)) }
    func setCurrentSpace(_ space: UInt64, display: String) { calls.append(.setCurrent(space, display: display)) }
    func hideSpaces(_ spaces: [UInt64]) { calls.append(.hide(spaces)) }
    func setSpaceOffset(_ space: UInt64, x: Double) { calls.append(.offset(space, x: x)) }
    /// The freeze handle `freezeScreen` returns; nil as if WindowServer refused.
    var freezeHandle: Int32? = 7
    func freezeScreen() -> Int32? { calls.append(.freeze); return freezeHandle }
    func dissolveScreen(_ freeze: Int32, duration: TimeInterval) { calls.append(.dissolve(freeze, duration: duration)) }
    func displayWidth(_ display: String) -> Double { 1000 }
    func windows(ofProcess pid: Int32) -> [AppWindow] { appWindows[pid] ?? [] }
    func enabledSystemShortcuts() -> [SystemShortcut] { shortcuts }
    func systemShortcutName(_ id: Int32) -> String? { names[id] }
    func eventTriggers(_ id: Int32, keyCode: Int, flags: UInt64) -> Bool {
        matchQueries.append((id, keyCode, flags))
        return triggers.contains("\(id)-\(keyCode)-\(flags)")
    }
}

/// Runs a slide only when the test calls `step` or `finish`.
private final class ManualAnimator: SlideAnimator {
    private(set) var duration: TimeInterval?
    private var step: ((Double) -> Void)?
    private var completion: (() -> Void)?
    var isRunning: Bool { completion != nil }

    func run(duration: TimeInterval, step: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        self.duration = duration
        self.step = step
        self.completion = completion
    }

    func step(to progress: Double) { step?(progress) }

    func finish() {
        let step = self.step, completion = self.completion
        self.step = nil
        self.completion = nil
        step?(1)
        completion?()
    }
}

/// A clock that only moves when the test moves it.
private final class Clock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

/// One display entry in the shape of SLSCopyManagedDisplaySpaces.
private func display(_ identifier: String, current: UInt64, spaces: [(UInt64, Int)]) -> [String: Any] {
    [
        "Display Identifier": identifier,
        "Current Space": ["ManagedSpaceID": NSNumber(value: current)],
        "Spaces": spaces.map { ["ManagedSpaceID": NSNumber(value: $0.0), "type": NSNumber(value: $0.1)] },
    ]
}

/// Desktops 1, 2, 3 (IDs 1, 475, 610) with a full-screen Space (600) between 2 and 3.
private let mainSpaces: [(UInt64, Int)] = [(1, 0), (475, 0), (600, 4), (610, 0)]

private func makeSwitcher(current: UInt64 = 1) -> (SpaceSwitcher, FakeServer, Clock) {
    let server = FakeServer(displays: [display("A", current: current, spaces: mainSpaces)], activeDisplay: "A")
    let clock = Clock()
    return (SpaceSwitcher(server: server, now: { clock.now }), server, clock)
}

private func makeAnimatedSwitcher(current: UInt64 = 1) -> (SpaceSwitcher, FakeServer, ManualAnimator) {
    let server = FakeServer(displays: [display("A", current: current, spaces: mainSpaces)], activeDisplay: "A")
    let animator = ManualAnimator()
    let switcher = SpaceSwitcher(server: server, animator: animator)
    switcher.animationDuration = 0.3
    return (switcher, server, animator)
}

@Suite struct SpaceSwitcherTests {
    @Test func switchShowsSetsAndHidesTheOthers() {
        let (switcher, server, _) = makeSwitcher()
        #expect(switcher.move(.right) == 475)
        #expect(server.calls == [.show([475]), .setCurrent(475, display: "A"), .hide([1, 600, 610])])
    }

    @Test func switchToTheCurrentSpaceDoesNothing() {
        let (switcher, server, _) = makeSwitcher(current: 475)
        switcher.switchTo(475, on: switcher.activeDisplay()!)
        #expect(server.calls.isEmpty)
    }

    @Test func moveStopsAtEitherEnd() {
        let (atStart, startServer, _) = makeSwitcher(current: 1)
        #expect(atStart.move(.left) == nil)
        #expect(startServer.calls.isEmpty)

        let (atEnd, endServer, _) = makeSwitcher(current: 610)
        #expect(atEnd.move(.right) == nil)
        #expect(endServer.calls.isEmpty)
    }

    @Test func moveWrapsAroundWhenSwitchedOn() {
        let (atEnd, server, _) = makeSwitcher(current: 610)
        atEnd.wrapsAround = true
        #expect(atEnd.move(.right) == 1)
        #expect(server.calls == [.show([1]), .setCurrent(1, display: "A"), .hide([475, 600, 610])])

        let (atStart, _, _) = makeSwitcher(current: 1)
        atStart.wrapsAround = true
        #expect(atStart.move(.left) == 610)
    }

    /// Two quick presses past the end: the second counts from the wrapped Space.
    @Test func quickPressesKeepWrapping() {
        let (switcher, _, clock) = makeSwitcher(current: 610)
        switcher.wrapsAround = true
        #expect(switcher.move(.right) == 1)
        clock.advance(0.1)
        #expect(switcher.move(.right) == 475)
    }

    @Test func moveIncludesFullScreenSpaces() {
        let (switcher, _, _) = makeSwitcher(current: 475)
        #expect(switcher.move(.right) == 600)
    }

    @Test func goToDesktopSkipsFullScreenSpaces() {
        let (switcher, server, _) = makeSwitcher()
        #expect(switcher.goToDesktop(3) == 610)
        #expect(server.calls.first == .show([610]))
        #expect(switcher.goToDesktop(4) == nil)
    }

    /// WindowServer still reports Space 1 right after the first switch; the
    /// second press must start from 475, not from 1 again.
    @Test func quickRepeatedPressesMoveOneSpaceEach() {
        let (switcher, server, clock) = makeSwitcher()
        #expect(switcher.move(.right) == 475)
        clock.advance(0.1)
        #expect(switcher.move(.right) == 600)
        #expect(server.calls.filter { if case .setCurrent = $0 { true } else { false } }
            == [.setCurrent(475, display: "A"), .setCurrent(600, display: "A")])
    }

    /// After the pending interval the switcher trusts WindowServer again, for
    /// example when the user switched with another tool in between.
    @Test func afterThePendingIntervalWindowServerWins() {
        let (switcher, server, clock) = makeSwitcher()
        #expect(switcher.move(.right) == 475)
        clock.advance(SpaceSwitcher.pendingInterval)
        server.displays = [display("A", current: 610, spaces: mainSpaces)]
        #expect(switcher.move(.left) == 600)
    }

    @Test func pendingSwitchOnlyAppliesToItsDisplay() {
        let server = FakeServer(displays: [
            display("A", current: 1, spaces: [(1, 0), (2, 0)]),
            display("B", current: 10, spaces: [(10, 0), (11, 0)]),
        ], activeDisplay: "A")
        let clock = Clock()
        let switcher = SpaceSwitcher(server: server, now: { clock.now })
        #expect(switcher.move(.right) == 2)
        server.activeDisplay = "B"
        #expect(switcher.currentSpace(of: switcher.activeDisplay()!) == 10)
        #expect(switcher.move(.right) == 11)
    }

    @Test func activeDisplayFollowsTheMenuBar() {
        let server = FakeServer(displays: [
            display("A", current: 1, spaces: [(1, 0)]),
            display("B", current: 10, spaces: [(10, 0)]),
        ], activeDisplay: "B")
        #expect(SpaceSwitcher(server: server).activeDisplay()?.identifier == "B")
    }

    /// With "Displays have separate Spaces" off, SkyLight lists one display
    /// named "Main" while the menu bar names a real display.
    @Test func activeDisplayFallsBackToTheFirst() {
        let server = FakeServer(displays: [display("Main", current: 1, spaces: [(1, 0), (2, 0)])],
                                activeDisplay: "56F3B652-546F-4DCC-A600-6D8FA010215F")
        let switcher = SpaceSwitcher(server: server)
        #expect(switcher.activeDisplay()?.identifier == "Main")
        #expect(switcher.move(.right) == 2)
        #expect(server.calls.contains(.setCurrent(2, display: "Main")))
    }

    @Test func noDisplaysMeansNoSwitch() {
        let server = FakeServer(displays: [], activeDisplay: nil)
        let switcher = SpaceSwitcher(server: server)
        #expect(switcher.move(.right) == nil)
        #expect(switcher.goToDesktop(1) == nil)
        #expect(server.calls.isEmpty)
    }

    /// WindowServer decides, for the event the keyboard sends (⌃← carries fn
    /// and numeric pad, 0xA40000), among the shortcuts that react to plain
    /// arrows; the tiling shortcut on the same key is not asked about.
    @Test func clashesAreDecidedByWindowServer() {
        let (switcher, server, _) = makeSwitcher()
        let bindings = HotKeyBinding.arrowKeys(.control)
        server.shortcuts = [SystemShortcut(id: 79, keyCode: bindings[0].keyCode, flags: 0x840000),
                            SystemShortcut(id: 240, keyCode: bindings[0].keyCode, flags: 0x840000)]
        server.names = [79: "WorkspacesLeft", 240: "WindowTileLeftHalf"]
        #expect(switcher.clashes(with: bindings).isEmpty)
        #expect(server.matchQueries.map(\.id) == [79])
        #expect(server.matchQueries.map(\.flags) == [0xA40000])

        server.triggers = ["79-\(bindings[0].keyCode)-\(0xA40000)", "240-\(bindings[0].keyCode)-\(0xA40000)"]
        let clashes = switcher.clashes(with: bindings)
        #expect(clashes.map(\.description) == ["⌃← also triggers “Move left a Space” (Mission Control)"])
    }

    @Test func slideMovesBothSpacesThenSwitches() {
        let (switcher, server, animator) = makeAnimatedSwitcher()
        #expect(switcher.move(.right) == 475)
        #expect(animator.duration == 0.3)
        // The new Space waits one display width to the right, is shown and
        // made current.
        #expect(server.calls == [.offset(475, x: 1000), .show([475]), .setCurrent(475, display: "A")])

        animator.step(to: 0.5)
        #expect(Array(server.calls.suffix(2)) == [.offset(1, x: -500), .offset(475, x: 500)])

        animator.finish()
        #expect(Array(server.calls.suffix(5)) == [
            .offset(1, x: -1000), .offset(475, x: 0),
            .hide([1, 600, 610]),
            .offset(1, x: 0), .offset(475, x: 0),
        ])
    }

    @Test func slideComesFromTheLeftWhenMovingLeft() {
        let (switcher, server, animator) = makeAnimatedSwitcher(current: 475)
        switcher.move(.left)
        #expect(server.calls.first == .offset(1, x: -1000))
        animator.finish()
    }

    /// Wrapping from the last Space to the first keeps the direction of the move.
    @Test func wrappingSlidesInTheDirectionOfTheMove() {
        let (switcher, server, animator) = makeAnimatedSwitcher(current: 610)
        switcher.wrapsAround = true
        #expect(switcher.move(.right) == 1)
        #expect(server.calls.first == .offset(1, x: 1000))
        animator.finish()
    }

    @Test func goToDesktopSlidesFromWhereTheDesktopLies() {
        let (switcher, server, animator) = makeAnimatedSwitcher(current: 610)
        #expect(switcher.goToDesktop(1) == 1)
        #expect(server.calls.first == .offset(1, x: -1000))
        animator.finish()
    }

    /// A press during a slide ends it at once and moves on from the new Space.
    @Test func switchDuringASlideFinishesItFirst() {
        let (switcher, server, animator) = makeAnimatedSwitcher()
        switcher.move(.right)
        animator.step(to: 0.3)
        #expect(switcher.move(.right) == 600)
        #expect(server.calls.contains(.setCurrent(475, display: "A")))
        #expect(animator.isRunning)
        #expect(Array(server.calls.suffix(3)) == [.offset(600, x: 1000), .show([600]), .setCurrent(600, display: "A")])
        #expect(server.calls.contains(.hide([1, 600, 610])))
        animator.finish()
    }

    @Test func zeroDurationSwitchesWithoutOffsets() {
        let (switcher, server, _) = makeAnimatedSwitcher()
        switcher.animationDuration = 0
        switcher.move(.right)
        #expect(server.calls == [.show([475]), .setCurrent(475, display: "A"), .hide([1, 600, 610])])
    }

    @Test func followActivationSwitchesToTheAppsWindow() {
        let (switcher, server, _) = makeSwitcher()
        server.appWindows[42] = [AppWindow(id: 7, spaces: [610], isShown: true)]
        #expect(switcher.followActivation(ofProcess: 42) == 610)
        #expect(server.calls == [.show([610]), .setCurrent(610, display: "A"), .hide([1, 475, 600])])
    }

    @Test func followActivationStaysWhenAWindowIsOnTheCurrentSpace() {
        let (switcher, server, _) = makeSwitcher()
        server.appWindows[42] = [AppWindow(id: 7, spaces: [610], isShown: true),
                                 AppWindow(id: 8, spaces: [1], isShown: true)]
        #expect(switcher.followActivation(ofProcess: 42) == nil)
        #expect(server.calls.isEmpty)
    }

    /// Right after a switch WindowServer can still report the old Space; the
    /// switcher counts from the Space it switched to.
    @Test func followActivationCountsFromAPendingSwitch() {
        let (switcher, server, _) = makeSwitcher()
        switcher.move(.right)
        server.appWindows[42] = [AppWindow(id: 7, spaces: [475], isShown: true)]
        #expect(switcher.followActivation(ofProcess: 42) == nil)
    }

    /// The screen is frozen, the switch happens at once underneath, and the
    /// frozen image dissolves over the duration; nothing slides.
    @Test func crossFadeFreezesSwitchesAndDissolves() {
        let (switcher, server, animator) = makeAnimatedSwitcher()
        switcher.transition = .crossFade
        #expect(switcher.move(.right) == 475)
        #expect(server.calls == [
            .freeze, .show([475]), .setCurrent(475, display: "A"), .hide([1, 600, 610]),
            .dissolve(7, duration: 0.3),
        ])
        #expect(!animator.isRunning)
    }

    @Test func crossFadeWithoutFreezeSwitchesAtOnce() {
        let (switcher, server, _) = makeAnimatedSwitcher()
        switcher.transition = .crossFade
        server.freezeHandle = nil
        switcher.move(.right)
        #expect(server.calls == [.freeze, .show([475]), .setCurrent(475, display: "A"), .hide([1, 600, 610])])
    }

    @Test func crossFadeWithoutDurationSwitchesAtOnce() {
        let (switcher, server, _) = makeAnimatedSwitcher()
        switcher.transition = .crossFade
        switcher.animationDuration = 0
        switcher.move(.right)
        #expect(server.calls == [.show([475]), .setCurrent(475, display: "A"), .hide([1, 600, 610])])
    }
}
