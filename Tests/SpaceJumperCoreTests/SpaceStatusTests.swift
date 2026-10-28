import Testing
@testable import SpaceJumperCore

private let spaces = [Space(id: 1, type: 0), Space(id: 475, type: 0), Space(id: 600, type: 4)]

@Suite struct SpaceStatusTests {
    @Test func everySpaceShowsItsPosition() {
        #expect(SpaceStatus.make(current: 475, spaces: spaces, numbering: .allSpaces)
                == SpaceStatus(title: "2", line: "Space 2 of 3"))
        #expect(SpaceStatus.make(current: 600, spaces: spaces, numbering: .allSpaces)
                == SpaceStatus(title: "3", line: "Space 3 of 3, full screen"))
    }

    @Test func desktopShowsItsNumber() {
        #expect(SpaceStatus.make(current: 475, spaces: spaces, numbering: .desktopsOnly)
                == SpaceStatus(title: "2", line: "Desktop 2 of 2"))
    }

    @Test func fullScreenSpaceShowsF() {
        #expect(SpaceStatus.make(current: 600, spaces: spaces, numbering: .desktopsOnly)
                == SpaceStatus(title: "F", line: "Full-screen Space"))
    }

    @Test func fullScreenSpaceCarriesItsAppName() {
        let named = [Space(id: 1, type: 0), Space(id: 600, type: 4, appPIDs: [42])]
        let appName: (Int32) -> String? = { $0 == 42 ? "Acrobat" : nil }
        #expect(SpaceStatus.make(current: 600, spaces: named, numbering: .allSpaces, appName: appName)
                == SpaceStatus(title: "2", line: "Space 2 of 2, full screen: Acrobat", name: "Acrobat"))
        #expect(SpaceStatus.make(current: 600, spaces: named, numbering: .desktopsOnly, appName: appName)
                == SpaceStatus(title: "F", line: "Full-screen Space: Acrobat", name: "Acrobat"))
        #expect(SpaceStatus.make(current: 1, spaces: named, numbering: .allSpaces, appName: appName)
                == SpaceStatus(title: "1", line: "Space 1 of 2"))
    }

    @Test func unknownSpaceIsUnavailable() {
        for numbering in SpaceNumbering.allCases {
            #expect(SpaceStatus.make(current: 999, spaces: spaces, numbering: numbering)
                    == SpaceStatus(title: "–", line: "No Spaces found."))
        }
    }

    @Test func unavailableCarriesTheReason() {
        #expect(SpaceStatus.unavailable("Missing in SkyLight: X.") == SpaceStatus(title: "–", line: "Missing in SkyLight: X."))
    }
}
