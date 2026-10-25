import Testing
@testable import InstantSpacesCore

private func began() -> DockSwipeEvent { DockSwipeEvent(phase: .began) }
private func changed(_ progress: Double) -> DockSwipeEvent { DockSwipeEvent(phase: .changed, progress: progress) }
private func ended(velocity: Double = 0) -> DockSwipeEvent { DockSwipeEvent(phase: .ended, velocity: velocity) }

@Suite struct SwipeInterceptorTests {
    @Test func oneSwipeSwitchesOnceAndHidesItFromTheDock() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(began()) == .drop)
        #expect(interceptor.handleCompanionGesture() == .drop)
        #expect(interceptor.handle(changed(0)) == .drop)
        #expect(interceptor.handle(changed(0.02)) == SwipeVerdict(.drop, switchDirection: .right))
        #expect(interceptor.handle(changed(0.3)) == .drop)
        #expect(interceptor.handle(changed(0.6)) == .drop)
        #expect(interceptor.handle(ended(velocity: 4)) == SwipeVerdict(.passWithoutMotion))
        #expect(!interceptor.isTracking)
        #expect(interceptor.handleCompanionGesture() == .pass)
    }

    @Test func negativeProgressIsLeft() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began())
        #expect(interceptor.handle(changed(-0.01)).switchDirection == .left)
    }

    /// A quick flick can end before any Changed event moved.
    @Test func endedVelocitySwitchesWhenProgressNeverMoved() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began())
        #expect(interceptor.handle(ended(velocity: -3)) == SwipeVerdict(.passWithoutMotion, switchDirection: .left))
    }

    @Test func endedWithoutAnyMotionDoesNotSwitch() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began())
        #expect(interceptor.handle(ended()) == SwipeVerdict(.passWithoutMotion))
    }

    @Test func beforeMacOS27TheEndedEventIsDropped() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: false)
        _ = interceptor.handle(began())
        _ = interceptor.handle(changed(0.1))
        #expect(interceptor.handle(ended(velocity: 2)) == .drop)
    }


    @Test func cancelledEndsTracking() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        _ = interceptor.handle(began())
        #expect(interceptor.handle(DockSwipeEvent(phase: .cancelled)) == .drop)
        #expect(interceptor.handle(changed(0.2)) == .pass)
    }

    /// Events of a swipe that began while the tap was off reach the Dock.
    @Test func eventsWithoutABeganPassThrough() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(changed(0.2)) == .pass)
        #expect(interceptor.handle(ended(velocity: 2)) == .pass)
        #expect(interceptor.handle(DockSwipeEvent(phase: .cancelled)) == .pass)
    }

    @Test func unknownPhasesFollowTheTracking() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        #expect(interceptor.handle(DockSwipeEvent(phase: .mayBegin)) == .pass)
        #expect(interceptor.handle(DockSwipeEvent(phase: nil)) == .pass)
        _ = interceptor.handle(began())
        #expect(interceptor.handle(DockSwipeEvent(phase: nil)) == .drop)
    }

    @Test func eachSwipeSwitchesAgain() {
        var interceptor = SwipeInterceptor(passesEndedWithoutMotion: true)
        for _ in 0..<2 {
            _ = interceptor.handle(began())
            #expect(interceptor.handle(changed(0.1)).switchDirection == .right)
            _ = interceptor.handle(ended(velocity: 1))
        }
    }
}
