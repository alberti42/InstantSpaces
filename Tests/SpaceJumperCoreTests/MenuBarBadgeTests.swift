import CoreGraphics
import Testing
@testable import SpaceJumperCore

@Suite struct MenuBarBadgeTests {
    @Test func roundedRectangleAddsPadding() {
        let layout = MenuBarBadgeLayout(textWidth: 8, shape: .roundedRectangle)
        #expect(layout == MenuBarBadgeLayout(textWidth: 7.5, shape: .roundedRectangle))
        #expect(layout.width == 16)
        #expect(layout.height == 16)
        #expect(layout.cornerRadius == 4)
    }

    /// One character in a capsule gives a circle.
    @Test func capsuleAroundOneCharacterIsACircle() {
        let layout = MenuBarBadgeLayout(textWidth: 6, shape: .capsule)
        #expect(layout.width == layout.height)
        #expect(layout.cornerRadius == layout.height / 2)
    }

    @Test func capsuleStretchesForTwoCharacters() {
        let layout = MenuBarBadgeLayout(textWidth: 16, shape: .capsule)
        #expect(layout.width == 24)
        #expect(layout.cornerRadius == 8)
    }

    @Test func settingsHaveTitles() {
        #expect(MenuBarFrame.allCases.map(\.title) == ["None", "Outline", "Filled"])
        #expect(MenuBarFrameShape.allCases.map(\.title) == ["Rounded Rectangle", "Capsule"])
    }
}
