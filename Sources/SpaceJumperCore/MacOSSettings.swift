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
    /// `com.apple.dock autohide`, "Automatically hide and show the Dock"; off
    /// by default.
    public var dockAutohides: Bool?
    /// `com.apple.dock autohide-delay`: seconds the pointer rests at the edge
    /// of a desktop before the hidden Dock appears. Not in System Settings.
    public var dockAutohideDelay: Double?
    /// `com.apple.dock digduration-duration`: seconds the pointer must keep
    /// pushing against the edge in a full-screen app before the hidden Dock
    /// appears. Not in System Settings.
    public var dockDigDuration: Double?
    /// `com.apple.dock autohide-time-modifier`: the hidden Dock's slide in and
    /// out, as a multiple of macOS's own; 0 shows it without the slide. Not in
    /// System Settings.
    public var dockAnimationModifier: Double?

    public init(threeFingerHorizontalSwipe: Int? = nil, fourFingerHorizontalSwipe: Int? = nil,
                rearrangesSpaces: Bool? = nil, switchesOnActivate: Bool? = nil, reducesMotion: Bool = false,
                dockAutohides: Bool? = nil, dockAutohideDelay: Double? = nil, dockDigDuration: Double? = nil,
                dockAnimationModifier: Double? = nil) {
        self.threeFingerHorizontalSwipe = threeFingerHorizontalSwipe
        self.fourFingerHorizontalSwipe = fourFingerHorizontalSwipe
        self.rearrangesSpaces = rearrangesSpaces
        self.switchesOnActivate = switchesOnActivate
        self.reducesMotion = reducesMotion
        self.dockAutohides = dockAutohides
        self.dockAutohideDelay = dockAutohideDelay
        self.dockDigDuration = dockDigDuration
        self.dockAnimationModifier = dockAnimationModifier
    }

    /// How an animated switch looks: a cross-fade while Reduce motion is on and
    /// SpaceJumper follows it, as macOS switches Spaces then; otherwise the slide.
    public func transition(followingReduceMotion follows: Bool) -> Transition {
        follows && reducesMotion ? .crossFade : .slide
    }

    /// What Reduce motion means for SpaceJumper's animation, for the Spaces tab.
    public func reduceMotionExplanation(followingReduceMotion follows: Bool) -> String {
        if !follows { return "The Spaces slide, whether Reduce motion is on or off." }
        return reducesMotion
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

    /// The Dock's own values when the keys are not set, from its
    /// `DockBarMouseEventHandler initWithConnection:` (macOS 27.0.1).
    public static let defaultDockAutohideDelay = 0.15
    public static let defaultDockDigDuration = 0.25

    public var dockAutohidesEffectively: Bool { dockAutohides ?? false }

    /// How long the pointer rests at the edge of a desktop before the hidden
    /// Dock appears, in milliseconds.
    public var dockDesktopWaitMilliseconds: Int {
        Self.milliseconds(dockAutohideDelay ?? Self.defaultDockAutohideDelay)
    }

    /// How long the pointer has to push against the edge in a full-screen app
    /// before the hidden Dock appears, in milliseconds.
    public var dockPushMilliseconds: Int {
        Self.milliseconds(dockDigDuration ?? Self.defaultDockDigDuration)
    }

    /// What the desktop wait does now, for the Dock section.
    public var dockDesktopWaitExplanation: String {
        dockDesktopWaitMilliseconds == 0
            ? "The Dock appears as soon as the pointer reaches the edge of a desktop."
            : "The Dock appears when the pointer has rested at the edge of a desktop for \(dockDesktopWaitMilliseconds) ms"
                + Self.defaultNote(dockDesktopWaitMilliseconds, Self.defaultDockAutohideDelay)
    }

    /// What the push does now, for the Dock section.
    public var dockPushExplanation: String {
        dockPushMilliseconds == 0
            ? "In a full-screen app, the Dock appears as soon as the pointer reaches the edge."
            : "In a full-screen app, the pointer has to keep pushing against the edge for \(dockPushMilliseconds) ms"
                + Self.defaultNote(dockPushMilliseconds, Self.defaultDockDigDuration)
                + " A pause starts the count again, and resting at the edge never shows the Dock."
    }

    private static func milliseconds(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }

    /// Ends a sentence about a wait: names macOS's default unless the wait is it.
    private static func defaultNote(_ milliseconds: Int, _ defaultSeconds: Double) -> String {
        let defaultMilliseconds = Self.milliseconds(defaultSeconds)
        return milliseconds == defaultMilliseconds
            ? ", macOS's default."
            : ". macOS's default is \(defaultMilliseconds) ms."
    }

    /// What the slide setting does now, for the Dock section.
    public var dockSlideExplanation: String {
        switch dockAnimationShare {
        case 0: return "The Dock is there at once, without sliding in or out."
        case 1: return "The Dock slides in and out as fast as macOS's default."
        default: return "The Dock slides in and out in \(Int((dockAnimationShare * 100).rounded())) % of macOS's default time."
        }
    }

    /// The Dock's slide as a share of macOS's, 0 … 1; 1 when the key is not set.
    public var dockAnimationShare: Double {
        min(max(dockAnimationModifier ?? 1, 0), 1)
    }

    /// Whether any of the keys SpaceJumper writes for the hidden Dock is set.
    public var changesDockTiming: Bool {
        dockAutohideDelay != nil || dockDigDuration != nil || dockAnimationModifier != nil
    }
}
