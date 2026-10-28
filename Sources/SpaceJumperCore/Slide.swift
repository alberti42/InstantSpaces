import Foundation

/// Where the two Spaces of a slide are drawn. The new Space comes in from the
/// side of `direction` (`.right`: from the right, as when moving one Space
/// right) while the old one leaves on the other side.
public struct Slide: Equatable, Sendable {
    public let direction: Direction
    /// The display width in points: how far each Space travels.
    public let width: Double

    public init(direction: Direction, width: Double) {
        self.direction = direction
        self.width = width
    }

    private var sign: Double { direction == .right ? 1 : -1 }

    /// The new Space's offset before the slide starts: one width to the side.
    public var startOffset: Double { sign * width }

    /// Offsets (in points, positive to the right) of the old and the new Space
    /// at `progress` from 0 to 1, eased in and out.
    public func offsets(at progress: Double) -> (old: Double, new: Double) {
        let eased = Self.easeInOut(progress)
        return (-sign * width * eased, sign * width * (1 - eased))
    }

    /// Quadratic ease-in-out; clamps to 0…1.
    public static func easeInOut(_ progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
    }
}

/// How an animated switch looks: the slide, or a cross-fade, which macOS
/// uses instead of its slide when Reduce motion is on.
public enum Transition: Sendable {
    case slide
    case crossFade
}

/// The opacity of the two Spaces of a cross-fade.
public enum CrossFade {
    /// Opacities of the old and the new Space at `progress` from 0 to 1,
    /// eased in and out like the slide.
    public static func alphas(at progress: Double) -> (old: Double, new: Double) {
        let eased = Slide.easeInOut(progress)
        return (1 - eased, eased)
    }
}

/// Runs a slide: calls `step` with the progress from 0 to 1 over `duration`,
/// then `completion`. `finish` ends a running slide at once (step 1, then
/// completion). Tests use their own, which steps when the test says so.
public protocol SlideAnimator: AnyObject {
    func run(duration: TimeInterval, step: @escaping (Double) -> Void, completion: @escaping () -> Void)
    func finish()
}

/// Steps a slide from a timer on the main run loop, about 120 times a second.
public final class TimerSlideAnimator: SlideAnimator {
    private var timer: Timer?
    private var step: ((Double) -> Void)?
    private var completion: (() -> Void)?

    public init() {}

    public func run(duration: TimeInterval, step: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        finish()
        self.step = step
        self.completion = completion
        let start = ProcessInfo.processInfo.systemUptime
        step(0)
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            let progress = (ProcessInfo.processInfo.systemUptime - start) / duration
            if progress >= 1 {
                self?.finish()
            } else {
                self?.step?(progress)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func finish() {
        timer?.invalidate()
        timer = nil
        let step = self.step, completion = self.completion
        self.step = nil
        self.completion = nil
        step?(1)
        completion?()
    }
}
