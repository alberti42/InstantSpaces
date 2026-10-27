import Foundation
import Testing
@testable import SpaceJumperCore

private let displayA = DisplaySpaces(identifier: "A", current: 1,
                                     spaces: [Space(id: 1, type: 0), Space(id: 475, type: 0), Space(id: 600, type: 4)])
private let displayB = DisplaySpaces(identifier: "B", current: 10, spaces: [Space(id: 10, type: 0), Space(id: 11, type: 0)])

private func target(_ windows: [AppWindow], current: Set<UInt64> = [1, 10]) -> UInt64? {
    ActivationTarget.find(windows: windows, displays: [displayA, displayB], currentSpaces: current)?.space
}

@Test func goesToTheSpaceOfTheFrontmostShownWindow() {
    #expect(target([AppWindow(id: 1, spaces: [475], isShown: true),
                    AppWindow(id: 2, spaces: [600], isShown: true)]) == 475)
}

@Test func staysWhenAShownWindowIsOnTheCurrentSpace() {
    #expect(target([AppWindow(id: 1, spaces: [475], isShown: true),
                    AppWindow(id: 2, spaces: [1], isShown: true)]) == nil)
}

/// A window on another display's current Space counts as visible.
@Test func staysWhenAShownWindowIsOnAnotherDisplaysCurrentSpace() {
    #expect(target([AppWindow(id: 1, spaces: [475], isShown: true),
                    AppWindow(id: 2, spaces: [10], isShown: true)]) == nil)
}

/// Minimized windows, windows of a hidden app and ordered-out windows keep a
/// Space but are not shown; macOS does not switch to them.
@Test func ignoresWindowsThatAreNotShown() {
    #expect(target([AppWindow(id: 1, spaces: [475], isShown: false)]) == nil)
    #expect(target([AppWindow(id: 1, spaces: [475], isShown: false),
                    AppWindow(id: 2, spaces: [600], isShown: true)]) == 600)
}

@Test func ignoresWindowsWithoutASpace() {
    #expect(target([AppWindow(id: 1, spaces: [], isShown: true)]) == nil)
    #expect(target([]) == nil)
}

/// A window on a current Space that is not shown (minimized there) does not
/// keep SpaceJumper from switching to a shown window elsewhere.
@Test func aMinimizedWindowOnTheCurrentSpaceDoesNotCount() {
    #expect(target([AppWindow(id: 1, spaces: [1], isShown: false),
                    AppWindow(id: 2, spaces: [475], isShown: true)]) == 475)
}

@Test func findsTheDisplayOfTheSpace() {
    let found = ActivationTarget.find(windows: [AppWindow(id: 1, spaces: [11], isShown: true)],
                                      displays: [displayA, displayB], currentSpaces: [1, 10])
    #expect(found?.space == 11)
    #expect(found?.display.identifier == "B")
}

@Test func ignoresSpacesThatNoDisplayHas() {
    #expect(target([AppWindow(id: 1, spaces: [999], isShown: true)]) == nil)
}

@Test func goesToAFullScreenSpace() {
    #expect(target([AppWindow(id: 1, spaces: [600], isShown: true)]) == 600)
}

@Suite struct SpaceChangeTrackerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func stillWhenWindowServerMatchesTheAnnouncement() {
        let tracker = SpaceChangeTracker(current: [4])
        #expect(!tracker.isChanging(current: [4], at: start))
    }

    /// WindowServer has made another Space current, and macOS has not
    /// announced it yet: the activation belongs to the change.
    @Test func changingBeforeTheAnnouncement() {
        let tracker = SpaceChangeTracker(current: [4])
        #expect(tracker.isChanging(current: [1], at: start))
    }

    @Test func changingForTheGracePeriodAfterTheAnnouncement() {
        var tracker = SpaceChangeTracker(current: [4])
        tracker.spaceDidChange(to: [1], at: start)
        #expect(tracker.isChanging(current: [1], at: start.addingTimeInterval(0.05)))
        #expect(!tracker.isChanging(current: [1], at: start.addingTimeInterval(SpaceChangeTracker.grace)))
    }

    @Test func resynchronizingHasNoGracePeriod() {
        var tracker = SpaceChangeTracker(current: [4])
        tracker.resynchronize([1])
        #expect(!tracker.isChanging(current: [1], at: start))
    }

    /// With several displays, a change on either counts.
    @Test func everyDisplayCounts() {
        let tracker = SpaceChangeTracker(current: [4, 10])
        #expect(tracker.isChanging(current: [4, 11], at: start))
        #expect(!tracker.isChanging(current: [10, 4], at: start))
    }
}
