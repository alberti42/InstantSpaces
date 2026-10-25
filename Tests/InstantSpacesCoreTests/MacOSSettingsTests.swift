import Testing
@testable import InstantSpacesCore

@Suite struct MacOSSettingsTests {
    @Test func swipeFingers() {
        #expect(MacOSSettings().swipeSetting == nil)
        #expect(MacOSSettings(threeFingerHorizontalSwipe: 2, fourFingerHorizontalSwipe: 2).swipeSetting
                == "Three Fingers")
        #expect(MacOSSettings(threeFingerHorizontalSwipe: 2, fourFingerHorizontalSwipe: 0).swipeSetting
                == "Three Fingers")
        #expect(MacOSSettings(threeFingerHorizontalSwipe: 0, fourFingerHorizontalSwipe: 2).swipeSetting
                == "Four Fingers")
        #expect(MacOSSettings(threeFingerHorizontalSwipe: 0, fourFingerHorizontalSwipe: 0).swipeSetting
                == "Off")
    }


    @Test func rearrangingIsOnByDefault() {
        #expect(MacOSSettings().rearrangesSpacesEffectively)
        #expect(MacOSSettings(rearrangesSpaces: true).rearrangesSpacesEffectively)
        #expect(!MacOSSettings(rearrangesSpaces: false).rearrangesSpacesEffectively)
        #expect(MacOSSettings().rearrangeExplanation.contains("turn this off"))
        #expect(MacOSSettings(rearrangesSpaces: false).rearrangeExplanation == "macOS keeps Spaces in the order you set (Desktop & Dock → Mission Control).")
    }
}
