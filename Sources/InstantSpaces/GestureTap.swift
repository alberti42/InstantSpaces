import AppKit
import ApplicationServices
import InstantSpacesCore

/// A session event tap that hands horizontal Dock swipes from the trackpad to
/// `SwipeInterceptor` and drops or edits them before the Dock sees them.
/// Changing events needs Accessibility permission; without it the tap cannot
/// be created.
@MainActor
final class GestureTap {
    /// Event fields of Dock swipes, as InstantSpaceSwitcher documents them
    /// (jurplel/InstantSpaceSwitcher, `Sources/ISS/ISS.c`).
    private enum Field {
        static let eventType = CGEventField(rawValue: 55)!
        static let hidType = CGEventField(rawValue: 110)!
        static let swipeMotion = CGEventField(rawValue: 123)!
        static let progress = CGEventField(rawValue: 124)!
        static let velocityX = CGEventField(rawValue: 129)!
        static let velocityY = CGEventField(rawValue: 130)!
        static let phase = CGEventField(rawValue: 132)!
    }

    private enum Value {
        static let gestureEvent: Int64 = 29
        static let dockControlEvent: Int64 = 30
        /// IOHIDEventType "Dock swipe".
        static let dockSwipe: Int64 = 23
        static let horizontalMotion: Int64 = 1
    }

    /// Called on the main thread for each swipe that should switch.
    var onSwitch: (Direction) -> Void = { _ in }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var interceptor = SwipeInterceptor(
        passesEndedWithoutMotion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27)

    var isRunning: Bool { tap != nil }

    static var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    /// Shows macOS's dialog that leads to Accessibility settings.
    static func requestAccessibilityPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    /// Creates the tap on the main run loop. Returns false without permission.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask = (1 << Value.gestureEvent) | (1 << Value.dockControlEvent)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<GestureTap>.fromOpaque(refcon).takeUnretainedValue()
            return MainActor.assumeIsolated { tap.handle(type: type, event: event) }
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            log.error("gesture tap: CGEvent.tapCreate failed (Accessibility permission: \(Self.hasAccessibilityPermission, privacy: .public))")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        let natural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool
        log.info("gesture tap started (natural scrolling: \(natural.map(String.init) ?? "unset", privacy: .public))")
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        interceptor = SwipeInterceptor(passesEndedWithoutMotion: interceptor.passesEndedWithoutMotion)
        log.info("gesture tap stopped")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS switches a tap off when its callback is too slow, or on user input.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            log.info("gesture tap re-enabled after \(type.rawValue, privacy: .public)")
            return Unmanaged.passUnretained(event)
        }

        let verdict: SwipeVerdict
        switch event.getIntegerValueField(Field.eventType) {
        case Value.gestureEvent:
            verdict = interceptor.handleCompanionGesture()
        case Value.dockControlEvent:
            guard event.getIntegerValueField(Field.hidType) == Value.dockSwipe,
                  event.getIntegerValueField(Field.swipeMotion) == Value.horizontalMotion,
                  // Real trackpad events come from the kernel, process 0.
                  event.getIntegerValueField(.eventSourceUnixProcessID) == 0
            else { return Unmanaged.passUnretained(event) }
            let swipe = DockSwipeEvent(
                phase: DockSwipeEvent.Phase(rawValue: Int(event.getIntegerValueField(Field.phase))),
                progress: event.getDoubleValueField(Field.progress),
                velocity: event.getDoubleValueField(Field.velocityX))
            let leftToDock = swipe.phase == .began && Self.dockExposeView().leavesSwipesToDock
            verdict = interceptor.handle(swipe, leftToDock: leftToDock)
            log.debug("swipe phase \(event.getIntegerValueField(Field.phase), privacy: .public) progress \(swipe.progress, privacy: .public) velocity \(swipe.velocity, privacy: .public) leftToDock \(leftToDock, privacy: .public) -> \(String(describing: verdict.action), privacy: .public) \(verdict.switchDirection?.rawValue ?? "", privacy: .public)")
        default:
            return Unmanaged.passUnretained(event)
        }

        if let direction = verdict.switchDirection {
            // Return from the callback first; the tap must stay fast.
            DispatchQueue.main.async { [weak self] in self?.onSwitch(direction) }
        }
        switch verdict.action {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .drop:
            return nil
        case .passWithoutMotion:
            event.setDoubleValueField(Field.progress, value: 0)
            event.setDoubleValueField(Field.velocityX, value: 0)
            event.setDoubleValueField(Field.velocityY, value: 0)
            return Unmanaged.passUnretained(event)
        }
    }

    /// Mission Control or App Exposé, from the Dock's accessibility tree; see
    /// `DockExposeView`. Asked once per swipe, at Began. A slow Dock counts
    /// as neither after 50 ms.
    private static func dockExposeView() -> DockExposeView {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return .none }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement]
        else { return .none }
        let identifiers = children.compactMap { child -> String? in
            var identifier: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXIdentifierAttribute as CFString, &identifier) == .success
            else { return nil }
            return identifier as? String
        }
        return DockExposeView(topLevelIdentifiers: identifiers)
    }
}
