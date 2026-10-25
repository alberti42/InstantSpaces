import Foundation
import Testing
@testable import SpaceJumperCore

private let spaces = [
    Space(id: 1, type: 0),
    Space(id: 475, type: 0),
    Space(id: 600, type: 4),
    Space(id: 610, type: 0),
]

@Test func neighbourMovesOneSpace() {
    #expect(SpaceNavigator.neighbour(of: 475, in: spaces, direction: .right) == 600)
    #expect(SpaceNavigator.neighbour(of: 475, in: spaces, direction: .left) == 1)
}

@Test func neighbourDoesNotWrapAround() {
    #expect(SpaceNavigator.neighbour(of: 1, in: spaces, direction: .left) == nil)
    #expect(SpaceNavigator.neighbour(of: 610, in: spaces, direction: .right) == nil)
}

@Test func neighbourWrapsAroundWhenAsked() {
    #expect(SpaceNavigator.neighbour(of: 610, in: spaces, direction: .right, wraps: true) == 1)
    #expect(SpaceNavigator.neighbour(of: 1, in: spaces, direction: .left, wraps: true) == 610)
    // Inside the list wrapping changes nothing.
    #expect(SpaceNavigator.neighbour(of: 475, in: spaces, direction: .right, wraps: true) == 600)
}

/// Full-screen Spaces are part of the cycle, as for the arrows.
@Test func wrapLandsOnAFullScreenSpaceAtTheEnd() {
    let endingFullScreen = [Space(id: 1, type: 0), Space(id: 2, type: 0), Space(id: 9, type: 4)]
    #expect(SpaceNavigator.neighbour(of: 1, in: endingFullScreen, direction: .left, wraps: true) == 9)
}

@Test func oneSpaceHasNoNeighbourEvenWhenWrapping() {
    let single = [Space(id: 1, type: 0)]
    #expect(SpaceNavigator.neighbour(of: 1, in: single, direction: .right, wraps: true) == nil)
    #expect(SpaceNavigator.neighbour(of: 1, in: single, direction: .left, wraps: true) == nil)
}

@Test func neighbourOfUnknownSpaceIsNil() {
    #expect(SpaceNavigator.neighbour(of: 999, in: spaces, direction: .right) == nil)
}

@Test func desktopNumbersSkipFullScreenSpaces() {
    #expect(SpaceNavigator.desktop(1, in: spaces) == 1)
    #expect(SpaceNavigator.desktop(3, in: spaces) == 610)
    #expect(SpaceNavigator.desktop(4, in: spaces) == nil)
    #expect(SpaceNavigator.desktop(0, in: spaces) == nil)
    #expect(SpaceNavigator.desktopNumber(of: 610, in: spaces) == 3)
    #expect(SpaceNavigator.desktopNumber(of: 600, in: spaces) == nil)
}

@Test func parsesManagedDisplaySpaces() {
    // Shape of SLSCopyManagedDisplaySpaces on macOS 27.0.1, reduced.
    let raw: [[String: Any]] = [[
        "Display Identifier": "56F3B652-546F-4DCC-A600-6D8FA010215F",
        "Current Space": ["ManagedSpaceID": NSNumber(value: 1), "type": NSNumber(value: 0)],
        "Spaces": [
            ["ManagedSpaceID": NSNumber(value: 1), "type": NSNumber(value: 0)],
            ["ManagedSpaceID": NSNumber(value: 475), "type": NSNumber(value: 0)],
        ],
    ]]
    let parsed = DisplaySpaces.parse(raw)
    #expect(parsed == [DisplaySpaces(
        identifier: "56F3B652-546F-4DCC-A600-6D8FA010215F",
        current: 1,
        spaces: [Space(id: 1, type: 0), Space(id: 475, type: 0)])])
}

@Test func parseSkipsIncompleteDisplays() {
    #expect(DisplaySpaces.parse([["Display Identifier": "Main"]]).isEmpty)
}
