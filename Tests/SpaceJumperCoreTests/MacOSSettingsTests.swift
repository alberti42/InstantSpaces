import Testing
@testable import SpaceJumperCore

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

    @Test func switchingOnActivateIsOnByDefault() {
        #expect(MacOSSettings().switchesOnActivateEffectively)
        #expect(!MacOSSettings(switchesOnActivate: false).switchesOnActivateEffectively)
        #expect(MacOSSettings().switchOnActivateExplanation(spaceJumperSwitches: true).contains("Turn this off"))
        #expect(MacOSSettings(switchesOnActivate: false).switchOnActivateExplanation(spaceJumperSwitches: true)
                == "SpaceJumper switches instead of macOS.")
    }

    /// Exactly one of macOS and SpaceJumper should switch on activation.
    @Test func switchOnActivateNeeded() {
        #expect(MacOSSettings().switchOnActivateNeeded(spaceJumperSwitches: true) == false)
        #expect(MacOSSettings().switchOnActivateNeeded(spaceJumperSwitches: false) == nil)
        #expect(MacOSSettings(switchesOnActivate: false).switchOnActivateNeeded(spaceJumperSwitches: true) == nil)
        #expect(MacOSSettings(switchesOnActivate: false).switchOnActivateNeeded(spaceJumperSwitches: false) == true)
    }

    @Test func reduceMotionChoosesTheCrossFade() {
        #expect(MacOSSettings().transition == .slide)
        #expect(MacOSSettings(reducesMotion: true).transition == .crossFade)
        #expect(MacOSSettings(reducesMotion: true).reduceMotionExplanation.contains("cross-fade instead"))
    }
}
