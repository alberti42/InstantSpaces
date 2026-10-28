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

@Test func numberingCountsEverySpaceOrOnlyDesktops() {
    #expect(SpaceNavigator.space(3, in: spaces, numbering: .allSpaces) == 600)
    #expect(SpaceNavigator.space(5, in: spaces, numbering: .allSpaces) == nil)
    #expect(SpaceNavigator.space(0, in: spaces, numbering: .allSpaces) == nil)
    #expect(SpaceNavigator.space(3, in: spaces, numbering: .desktopsOnly) == 610)
    #expect(SpaceNavigator.number(of: 600, in: spaces, numbering: .allSpaces) == 3)
    #expect(SpaceNavigator.number(of: 610, in: spaces, numbering: .allSpaces) == 4)
    #expect(SpaceNavigator.number(of: 600, in: spaces, numbering: .desktopsOnly) == nil)
    #expect(SpaceNavigator.number(of: 610, in: spaces, numbering: .desktopsOnly) == 3)
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

@Test func parsesTheAppsOfFullScreenSpaces() {
    // A full-screen Space lists its windows' processes under TileLayoutManager
    // (macOS 27.0.1, reduced); split view has two tiles.
    func tile(_ pid: Int32) -> [String: Any] { ["pid": NSNumber(value: pid), "type": NSNumber(value: 5)] }
    let raw: [[String: Any]] = [[
        "Display Identifier": "Main",
        "Current Space": ["ManagedSpaceID": NSNumber(value: 1)],
        "Spaces": [
            ["ManagedSpaceID": NSNumber(value: 1), "type": NSNumber(value: 0)],
            ["ManagedSpaceID": NSNumber(value: 170), "type": NSNumber(value: 4), "pid": NSNumber(value: 43733),
             "TileLayoutManager": ["TileSpaces": [tile(43733)]]],
            ["ManagedSpaceID": NSNumber(value: 180), "type": NSNumber(value: 4), "pid": NSNumber(value: 10),
             "TileLayoutManager": ["TileSpaces": [tile(10), tile(20)]]],
            ["ManagedSpaceID": NSNumber(value: 190), "type": NSNumber(value: 4), "pid": NSNumber(value: 30)],
        ],
    ]]
    #expect(DisplaySpaces.parse(raw).first?.spaces == [
        Space(id: 1, type: 0),
        Space(id: 170, type: 4, appPIDs: [43733]),
        Space(id: 180, type: 4, appPIDs: [10, 20]),
        Space(id: 190, type: 4, appPIDs: [30]),
    ])
}

@Test func missionControlNamesFullScreenSpacesOnly() {
    let names: [Int32: String] = [10: "Safari", 20: "Notes"]
    let appName: (Int32) -> String? = { names[$0] }
    #expect(Space(id: 1, type: 0, appPIDs: [10]).missionControlName(appName: appName) == nil)
    #expect(Space(id: 2, type: 4, appPIDs: [10]).missionControlName(appName: appName) == "Safari")
    #expect(Space(id: 3, type: 4, appPIDs: [10, 20]).missionControlName(appName: appName) == "Safari & Notes")
    #expect(Space(id: 4, type: 4, appPIDs: [99]).missionControlName(appName: appName) == nil)
}

@Test func parseSkipsIncompleteDisplays() {
    #expect(DisplaySpaces.parse([["Display Identifier": "Main"]]).isEmpty)
}
