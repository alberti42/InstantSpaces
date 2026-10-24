import Foundation
import Testing
@testable import InstantSpacesCore

/// A `SpaceServer` that serves fixed displays and records the switch calls.
private final class FakeServer: SpaceServer {
    enum Call: Equatable {
        case show([UInt64])
        case setCurrent(UInt64, display: String)
        case hide([UInt64])
    }

    var displays: [[String: Any]]
    var activeDisplay: String?
    var enabledHotKeys: Set<Int32> = []
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
    func isSymbolicHotKeyEnabled(_ hotKey: Int32) -> Bool { enabledHotKeys.contains(hotKey) }
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

    @Test func systemHotKeysAreReadFromTheServer() {
        let (switcher, server, _) = makeSwitcher()
        #expect(!switcher.isSystemHotKeyEnabled(.moveLeftASpace))
        server.enabledHotKeys = [79]
        #expect(switcher.isSystemHotKeyEnabled(.moveLeftASpace))
        #expect(!switcher.isSystemHotKeyEnabled(.moveRightASpace))
    }
}
