/// One horizontal Dock swipe event from the trackpad (event type 30, "Dock
/// control", with IOHIDEventType 23, "Dock swipe"), reduced to what the
/// interceptor needs. Field numbers are in the app's `GestureTap`; they follow
/// InstantSpaceSwitcher (jurplel/InstantSpaceSwitcher, `Sources/ISS/ISS.c`).
public struct DockSwipeEvent: Equatable, Sendable {
    public enum Phase: Int, Sendable {
        case began = 1
        case changed = 2
        case ended = 4
        case cancelled = 8
        case mayBegin = 128
    }

    /// Nil for a phase value the interceptor does not know.
    public let phase: Phase?
    /// How far the swipe has moved (field 124); its sign gives the direction.
    public let progress: Double
    /// Horizontal velocity (field 129), set on the Ended event.
    public let velocity: Double

    public init(phase: Phase?, progress: Double = 0, velocity: Double = 0) {
        self.phase = phase
        self.progress = progress
        self.velocity = velocity
    }
}

/// What to do with an intercepted event.
public struct SwipeVerdict: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        /// Hand the event on unchanged.
        case pass
        /// Remove the event; the Dock never sees it.
        case drop
        /// Hand the event on with progress and velocity set to zero, so the
        /// Dock closes its gesture state without switching.
        case passWithoutMotion
    }

    public let action: Action
    /// Switch one Space in this direction.
    public let switchDirection: Direction?

    public init(_ action: Action, switchDirection: Direction? = nil) {
        self.action = action
        self.switchDirection = switchDirection
    }

    public static let pass = SwipeVerdict(.pass)
    public static let drop = SwipeVerdict(.drop)
}

/// Replaces the Dock's animated swipe with one instant switch per swipe.
///
/// The Began event is dropped, so the Dock never starts its slide. The first
/// Changed event with nonzero progress gives the direction and triggers the
/// switch; later Changed events are dropped. If the swipe ends before any
/// progress, the Ended event's velocity gives the direction. The Ended event
/// itself is dropped before macOS 27; from macOS 27 on, the Dock needs it to
/// close its gesture state, so it is passed on without motion.
public struct SwipeInterceptor: Sendable {
    /// Whether Ended events are passed on without motion (macOS 27 and later)
    /// instead of dropped.
    public let passesEndedWithoutMotion: Bool
    public private(set) var isTracking = false
    private var hasSwitched = false

    public init(passesEndedWithoutMotion: Bool) {
        self.passesEndedWithoutMotion = passesEndedWithoutMotion
    }

    /// Progress or velocity greater than zero means right.
    public static func direction(for value: Double) -> Direction? {
        value == 0 ? nil : (value > 0 ? .right : .left)
    }

    /// `leftToDock`: the swipe begins in a Dock view that handles swipes
    /// itself (App Exposé, see `DockExposeView`); all its events are passed
    /// on. Swipes inside Mission Control are intercepted: the switch is
    /// instant there as well, and Mission Control shows the new Space.
    public mutating func handle(_ event: DockSwipeEvent, leftToDock: Bool = false) -> SwipeVerdict {
        switch event.phase {
        case .began:
            if leftToDock {
                isTracking = false
                return .pass
            }
            isTracking = true
            hasSwitched = false
            return .drop

        case .changed:
            guard isTracking else { return .pass }
            if !hasSwitched, let direction = Self.direction(for: event.progress) {
                hasSwitched = true
                return SwipeVerdict(.drop, switchDirection: direction)
            }
            return .drop

        case .ended:
            guard isTracking else { return .pass }
            let direction = hasSwitched ? nil : Self.direction(for: event.velocity)
            isTracking = false
            hasSwitched = false
            return SwipeVerdict(passesEndedWithoutMotion ? .passWithoutMotion : .drop, switchDirection: direction)

        case .cancelled:
            guard isTracking else { return .pass }
            isTracking = false
            hasSwitched = false
            return .drop

        case .mayBegin, nil:
            return isTracking ? .drop : .pass
        }
    }

    /// The gesture events (type 29) that accompany Dock swipe events are
    /// dropped while a swipe is intercepted.
    public func handleCompanionGesture() -> SwipeVerdict {
        isTracking ? .drop : .pass
    }
}

/// The Exposé view the Dock shows, judged from the identifiers of the Dock's
/// top-level accessibility elements: Mission Control adds a group with
/// identifier `mc`, App Exposé one with `appexpose` (macOS 27.0.1).
public enum DockExposeView: Equatable, Sendable {
    case none
    case missionControl
    case appExpose

    public init(topLevelIdentifiers identifiers: [String]) {
        if identifiers.contains("appexpose") {
            self = .appExpose
        } else if identifiers.contains("mc") {
            self = .missionControl
        } else {
            self = .none
        }
    }

    /// In App Exposé macOS does not switch Spaces on a swipe, so swipes are
    /// left to the Dock there.
    public var leavesSwipesToDock: Bool { self == .appExpose }
}
