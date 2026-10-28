/// The macOS settings that change how SpaceJumper behaves, as the Settings
/// window reports them. Nil means the preference is not set.
public struct MacOSSettings: Equatable, Sendable {
    /// `com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture`;
    /// 2 swipes between Spaces ("full-screen applications").
    public var threeFingerHorizontalSwipe: Int?
    /// `com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture`; 2 as above.
    public var fourFingerHorizontalSwipe: Int?
    /// `com.apple.dock mru-spaces`, "Automatically rearrange Spaces based on
    /// most recent use"; on by default.
    public var rearrangesSpaces: Bool?
    /// `AppleSpacesSwitchOnActivate` in the global domain, "When switching to
    /// an application, switch to a Space with open windows for the
    /// application"; on by default.
    public var switchesOnActivate: Bool?
    /// Reduce motion (System Settings → Accessibility → Motion), as
    /// `NSWorkspace.accessibilityDisplayShouldReduceMotion` reports it.
    public var reducesMotion: Bool

    public init(threeFingerHorizontalSwipe: Int? = nil, fourFingerHorizontalSwipe: Int? = nil,
                rearrangesSpaces: Bool? = nil, switchesOnActivate: Bool? = nil, reducesMotion: Bool = false) {
        self.threeFingerHorizontalSwipe = threeFingerHorizontalSwipe
        self.fourFingerHorizontalSwipe = fourFingerHorizontalSwipe
        self.rearrangesSpaces = rearrangesSpaces
        self.switchesOnActivate = switchesOnActivate
        self.reducesMotion = reducesMotion
    }

    /// How an animated switch looks: a cross-fade while Reduce motion is on,
    /// as macOS switches Spaces then; otherwise the slide.
    public var transition: Transition { reducesMotion ? .crossFade : .slide }

    /// What Reduce motion means for SpaceJumper's animation, for the General tab.
    public var reduceMotionExplanation: String {
        reducesMotion
            ? "The Spaces cross-fade instead of sliding, as macOS does without SpaceJumper."
            : "The Spaces slide. With Reduce motion on, they cross-fade instead, as macOS does without SpaceJumper."
    }

    private static let swipesBetweenSpaces = 2

    /// How swiping between Spaces is set in Trackpad → More Gestures → Swipe
    /// between full-screen applications, in the Trackpad pane's own labels
    /// (`THREEFINGER`, `FOURFINGER`, `GNAME_OFF`); nil when the trackpad
    /// preferences are not set. With both keys at 2 it is three fingers.
    /// Choosing Dragging style Three Finger Drag sets the three-finger key to
    /// 0, and choosing three fingers here turns Three Finger Drag off, so the
    /// two never conflict.
    public var swipeSetting: String? {
        guard threeFingerHorizontalSwipe != nil || fourFingerHorizontalSwipe != nil else { return nil }
        if threeFingerHorizontalSwipe == Self.swipesBetweenSpaces { return "Three Fingers" }
        if fourFingerHorizontalSwipe == Self.swipesBetweenSpaces { return "Four Fingers" }
        return "Off"
    }

    /// Whether macOS reorders Spaces by recent use. macOS stores no value
    /// while the option has its default, on (confirmed on macOS 27.0.1).
    public var rearrangesSpacesEffectively: Bool { rearrangesSpaces ?? true }

    /// What the rearranging means for SpaceJumper, for the General tab. It
    /// does not conflict with SpaceJumper, which follows the order macOS
    /// shows.
    public var rearrangeExplanation: String {
        rearrangesSpacesEffectively
            ? "macOS moves Spaces as you use them, so desktop numbers can change. SpaceJumper follows the order macOS shows. To keep the order fixed, turn this off in Desktop & Dock → Mission Control."
            : "macOS keeps Spaces in the order you set (Desktop & Dock → Mission Control)."
    }

    /// Whether macOS switches Spaces when an app is activated. The key was
    /// absent on macOS 27.0.1 with the option on.
    public var switchesOnActivateEffectively: Bool { switchesOnActivate ?? true }

    /// Whether the macOS option has to change for SpaceJumper's setting:
    /// off when SpaceJumper switches on activation (with both on, macOS slides
    /// first), on when it does not (with both off, activating an app never
    /// changes the Space). Nil when the option already fits.
    public func switchOnActivateNeeded(spaceJumperSwitches: Bool) -> Bool? {
        switchesOnActivateEffectively == spaceJumperSwitches ? !spaceJumperSwitches : nil
    }

    /// What the macOS option means for SpaceJumper's switch on activation,
    /// for the General tab.
    public func switchOnActivateExplanation(spaceJumperSwitches: Bool) -> String {
        switch (switchesOnActivateEffectively, spaceJumperSwitches) {
        case (true, true):
            return "macOS switches first, with its slide. Turn this off so that SpaceJumper switches instead."
        case (true, false):
            return "macOS switches with its slide."
        case (false, true):
            return "SpaceJumper switches instead of macOS."
        case (false, false):
            return "Activating an app does not change the Space. Turn this on so that macOS switches again."
        }
    }
}
