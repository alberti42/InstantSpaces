import Testing
@testable import InstantSpacesCore

@Suite struct SlideTests {
    @Test func rightSlideStartsOneWidthToTheRight() {
        let slide = Slide(direction: .right, width: 1000)
        #expect(slide.startOffset == 1000)
        #expect(slide.offsets(at: 0) == (old: 0, new: 1000))
        #expect(slide.offsets(at: 1) == (old: -1000, new: 0))
    }

    @Test func leftSlideMirrorsIt() {
        let slide = Slide(direction: .left, width: 1000)
        #expect(slide.startOffset == -1000)
        #expect(slide.offsets(at: 1) == (old: 1000, new: 0))
    }

    @Test func easingIsSymmetricAndClamped() {
        #expect(Slide.easeInOut(0) == 0)
        #expect(Slide.easeInOut(0.5) == 0.5)
        #expect(Slide.easeInOut(1) == 1)
        #expect(Slide.easeInOut(0.25) == 0.125)
        #expect(Slide.easeInOut(0.75) == 0.875)
        #expect(Slide.easeInOut(-1) == 0)
        #expect(Slide.easeInOut(2) == 1)
    }
}
