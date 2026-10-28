import Foundation
import os

public let log = Logger(subsystem: "io.alberti42.SpaceJumper", category: "switch")

/// Switches Spaces: show the new Space, make it current, hide the others.
/// WindowServer does this at once; the Dock, which draws macOS's slide, is not
/// involved. With an `animationDuration`, the switcher draws its own slide by
/// shifting the two Spaces on screen before the switch completes.
public final class SpaceSwitcher {
    /// The bridged operations are asynchronous, so WindowServer can still report
    /// the old Space right after a switch. For this long after a switch, the
    /// switcher counts from the Space it switched to, so that quick repeated
    /// presses move one Space each.
    public static let pendingInterval: TimeInterval = 0.5

    /// Whether `move` goes from the last Space to the first and back, instead
    /// of stopping at the ends as macOS does.
    public var wrapsAround = false

    /// How long a switch slides; 0 switches at once.
    public var animationDuration: TimeInterval = 0

    /// Whether an animated switch slides or cross-fades.
    public var transition: Transition = .slide

    private let server: SpaceServer
    private let now: () -> Date
    private let animator: SlideAnimator
    private var pending: (display: String, space: UInt64, time: Date)?

    /// `now` is the clock for the pending interval and `animator` runs slides;
    /// tests pass their own.
    public init(server: SpaceServer, now: @escaping () -> Date = Date.init,
                animator: SlideAnimator = TimerSlideAnimator()) {
        self.server = server
        self.now = now
        self.animator = animator
    }

    /// A switcher that talks to WindowServer through SkyLight.
    public convenience init() throws {
        try self.init(server: SkyLightServer())
    }

    public func displays() -> [DisplaySpaces] {
        DisplaySpaces.parse(server.managedDisplaySpaces())
    }

    /// The display with the active menu bar. When displays share Spaces,
    /// SkyLight lists a single display named "Main", which is returned instead.
    public func activeDisplay() -> DisplaySpaces? {
        let all = displays()
        let active = server.activeMenuBarDisplay()
        return all.first { $0.identifier == active } ?? all.first
    }

    /// The current Space of `display`, taking a switch still in progress into account.
    public func currentSpace(of display: DisplaySpaces) -> UInt64 {
        if let pending, pending.display == display.identifier,
           now().timeIntervalSince(pending.time) < Self.pendingInterval {
            return pending.space
        }
        return display.current
    }

    /// Moves one Space left or right on the active display. Returns the Space
    /// switched to, or nil at either end unless `wrapsAround`.
    @discardableResult
    public func move(_ direction: Direction) -> UInt64? {
        guard let display = activeDisplay(),
              let target = SpaceNavigator.neighbour(of: currentSpace(of: display), in: display.spaces,
                                                    direction: direction, wraps: wrapsAround)
        else { return nil }
        switchTo(target, on: display, direction: direction)
        return target
    }

    /// Goes to user desktop `number` (1-based) on the active display.
    @discardableResult
    public func goToDesktop(_ number: Int) -> UInt64? {
        guard let display = activeDisplay(),
              let target = SpaceNavigator.desktop(number, in: display.spaces)
        else { return nil }
        switchTo(target, on: display)
        return target
    }

    /// Switches to the Space of the frontmost window of process `pid` that
    /// appears on activation (see `ActivationTarget.find`), for an app that
    /// was just activated. Returns the Space switched to, or nil when such a
    /// window is already on a current Space or there is none.
    @discardableResult
    public func followActivation(ofProcess pid: Int32) -> UInt64? {
        let all = displays()
        guard let target = ActivationTarget.find(windows: server.windows(ofProcess: pid), displays: all,
                                                 currentSpaces: Set(all.map(currentSpace(of:))))
        else { return nil }
        switchTo(target.space, on: target.display)
        return target.space
    }

    /// Switches `display` to `space`. Every other Space of the display is
    /// hidden, not only the current one, so a wrong idea of the current Space
    /// cannot leave two Spaces on screen.
    ///
    /// With an `animationDuration` the new Space slides in from `direction`;
    /// without one, from the side where it lies in Mission Control. It is made
    /// current when the slide starts and the others are hidden when it ends:
    /// a window that appears on the new Space during the slide is then on the
    /// current Space, and the Dock does not start its own switch to it. A switch during a slide first
    /// ends that slide at once.
    public func switchTo(_ space: UInt64, on display: DisplaySpaces, direction: Direction? = nil) {
        animator.finish()
        let current = currentSpace(of: display)
        guard space != current else { return }
        log.info("switch \(current, privacy: .public) -> \(space, privacy: .public) on \(display.identifier, privacy: .public)")
        let others = display.spaces.map(\.id).filter { $0 != space }
        guard animationDuration > 0 else {
            server.showSpaces([space])
            server.setCurrentSpace(space, display: display.identifier)
            server.hideSpaces(others)
            pending = (display.identifier, space, now())
            return
        }

        if transition == .crossFade {
            crossFade(from: current, to: space, on: display, hiding: others)
            return
        }

        let ids = display.spaces.map(\.id)
        let side = direction
            ?? ((ids.firstIndex(of: space) ?? 0) > (ids.firstIndex(of: current) ?? 0) ? .right : .left)
        let slide = Slide(direction: side, width: server.displayWidth(display.identifier))
        // Until the slide ends and WindowServer catches up, count from the new Space.
        pending = (display.identifier, space, now().addingTimeInterval(animationDuration))
        server.setSpaceOffset(space, x: slide.startOffset)
        server.showSpaces([space])
        server.setCurrentSpace(space, display: display.identifier)
        animator.run(duration: animationDuration, step: { [server] progress in
            let offsets = slide.offsets(at: progress)
            server.setSpaceOffset(current, x: offsets.old)
            server.setSpaceOffset(space, x: offsets.new)
        }, completion: { [weak self, server] in
            server.hideSpaces(others)
            server.setSpaceOffset(current, x: 0)
            server.setSpaceOffset(space, x: 0)
            if let self { self.pending = (display.identifier, space, self.now()) }
        })
    }

    /// The animated switch with `transition` `.crossFade`, in the order of the
    /// slide: the new Space is shown transparent and made current, both
    /// opacities change, then the others are hidden and both are opaque again.
    private func crossFade(from current: UInt64, to space: UInt64, on display: DisplaySpaces, hiding others: [UInt64]) {
        pending = (display.identifier, space, now().addingTimeInterval(animationDuration))
        server.setSpaceAlpha(space, alpha: 0)
        server.showSpaces([space])
        server.setCurrentSpace(space, display: display.identifier)
        animator.run(duration: animationDuration, step: { [server] progress in
            let alphas = CrossFade.alphas(at: progress)
            server.setSpaceAlpha(current, alpha: alphas.old)
            server.setSpaceAlpha(space, alpha: alphas.new)
        }, completion: { [weak self, server] in
            server.hideSpaces(others)
            server.setSpaceAlpha(current, alpha: 1)
            server.setSpaceAlpha(space, alpha: 1)
            if let self { self.pending = (display.identifier, space, self.now()) }
        })
    }

    /// The bindings among `bindings` that would also trigger a switched-on
    /// macOS shortcut (see `ShortcutClash.find`). Names are looked up only for
    /// shortcuts on the keys of `bindings`.
    public func clashes(with bindings: [HotKeyBinding]) -> [ShortcutClash] {
        let keys = Set(bindings.map(\.keyCode))
        let candidates = server.enabledSystemShortcuts().filter { keys.contains($0.keyCode) }.map { shortcut in
            var named = shortcut
            named.identifier = server.systemShortcutName(shortcut.id)
            return named
        }
        return ShortcutClash.find(bindings, in: candidates) { binding, shortcut in
            server.eventTriggers(shortcut.id, keyCode: binding.keyCode, flags: binding.keyboardEventFlags)
        }
    }
}
