import Testing
@testable import InstantSpacesCore

private func began() -> DockSwipeEvent { DockSwipeEvent(phase: .began) }
private func changed(_ progress: Double) -> DockSwipeEvent { DockSwipeEvent(phase: .changed, progress: progress) }
private func ended(velocity: Double = 0) -> DockSwipeEvent { DockSwipeEvent(phase: .ended, velocity: velocity) }

@Suite struct SwipeInterceptorTests {
    @Test func oneSwipeSwitchesOnceAndHidesItFromTheDock() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(began(), overlayIsOpen: false) == .drop)
        #expect(interceptor.handleCompanionGesture() == .drop)
        #expect(interceptor.handle(changed(0), overlayIsOpen: false) == .drop)
        #expect(interceptor.handle(changed(0.02), overlayIsOpen: false) == SwipeVerdict(.drop, switchDirection: .right))
        #expect(interceptor.handle(changed(0.3), overlayIsOpen: false) == .drop)
        #expect(interceptor.handle(changed(0.6), overlayIsOpen: false) == .drop)
        #expect(interceptor.handle(ended(velocity: 4), overlayIsOpen: false) == SwipeVerdict(.passWithoutMotion))
        #expect(!interceptor.isTracking)
        #expect(interceptor.handleCompanionGesture() == .pass)
    }

    @Test func negativeProgressIsLeft() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        #expect(interceptor.handle(changed(-0.01), overlayIsOpen: false).switchDirection == .left)
    }

    /// A quick flick can end before any Changed event moved.
    @Test func endedVelocitySwitchesWhenProgressNeverMoved() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        #expect(interceptor.handle(ended(velocity: -3), overlayIsOpen: false) == SwipeVerdict(.passWithoutMotion, switchDirection: .left))
    }

    @Test func endedWithoutAnyMotionDoesNotSwitch() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        #expect(interceptor.handle(ended(), overlayIsOpen: false) == SwipeVerdict(.passWithoutMotion))
    }

    @Test func beforeMacOS27TheEndedEventIsDropped() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: false)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        _ = interceptor.handle(changed(0.1), overlayIsOpen: false)
        #expect(interceptor.handle(ended(velocity: 2), overlayIsOpen: false) == .drop)
    }

    @Test func swipesStartedWithAnOverlayOpenAreLeftToTheDock() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(began(), overlayIsOpen: true) == .pass)
        #expect(interceptor.handleCompanionGesture() == .pass)
        #expect(interceptor.handle(changed(0.2), overlayIsOpen: false) == .pass)
        #expect(interceptor.handle(ended(velocity: 2), overlayIsOpen: false) == .pass)
    }

    @Test func cancelledEndsTracking() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        #expect(interceptor.handle(DockSwipeEvent(phase: .cancelled), overlayIsOpen: false) == .drop)
        #expect(interceptor.handle(changed(0.2), overlayIsOpen: false) == .pass)
    }

    /// Events of a swipe that began while the tap was off reach the Dock.
    @Test func eventsWithoutABeganPassThrough() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(changed(0.2), overlayIsOpen: false) == .pass)
        #expect(interceptor.handle(ended(velocity: 2), overlayIsOpen: false) == .pass)
        #expect(interceptor.handle(DockSwipeEvent(phase: .cancelled), overlayIsOpen: false) == .pass)
    }

    @Test func unknownPhasesFollowTheTracking() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(DockSwipeEvent(phase: .mayBegin), overlayIsOpen: false) == .pass)
        #expect(interceptor.handle(DockSwipeEvent(phase: nil), overlayIsOpen: false) == .pass)
        _ = interceptor.handle(began(), overlayIsOpen: false)
        #expect(interceptor.handle(DockSwipeEvent(phase: nil), overlayIsOpen: false) == .drop)
    }

    @Test func eachSwipeSwitchesAgain() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        for _ in 0..<2 {
            _ = interceptor.handle(began(), overlayIsOpen: false)
            #expect(interceptor.handle(changed(0.1), overlayIsOpen: false).switchDirection == .right)
            _ = interceptor.handle(ended(velocity: 1), overlayIsOpen: false)
        }
    }

    @Test func overlayHeuristic() {
        #expect(DockOverlay.isOpen(dockWindowLayers: [20, 18, 20]))
        #expect(!DockOverlay.isOpen(dockWindowLayers: [20]))
        #expect(!DockOverlay.isOpen(dockWindowLayers: [18]))
        #expect(!DockOverlay.isOpen(dockWindowLayers: []))
    }
}
