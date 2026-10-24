import Testing
@testable import InstantSpacesCore

private let spaces = [Space(id: 1, type: 0), Space(id: 475, type: 0), Space(id: 600, type: 4)]

@Suite struct SpaceStatusTests {
    @Test func desktopShowsItsNumber() {
        #expect(SpaceStatus.make(current: 475, spaces: spaces) == SpaceStatus(title: "2", line: "Desktop 2 of 2"))
    }

    @Test func fullScreenSpaceShowsF() {
        #expect(SpaceStatus.make(current: 600, spaces: spaces) == SpaceStatus(title: "F", line: "Full-screen Space"))
    }

    @Test func unknownSpaceIsUnavailable() {
        #expect(SpaceStatus.make(current: 999, spaces: spaces) == SpaceStatus(title: "–", line: "No Spaces found."))
    }

    @Test func unavailableCarriesTheReason() {
        #expect(SpaceStatus.unavailable("Missing in SkyLight: X.") == SpaceStatus(title: "–", line: "Missing in SkyLight: X."))
    }
}
