import Testing
@testable import SpaceJumperCore

@Suite struct DiagnosticsTests {
    private func sample() -> Diagnostics {
        var d = Diagnostics()
        d.version = "0.3.1 (build 6)"
        d.accessibilityGranted = true
        d.swipeTapRunning = true
        d.displays = [DisplaySpaces(identifier: "A", current: 5,
                                    spaces: [Space(id: 1, type: 0), Space(id: 5, type: 0), Space(id: 600, type: 4)])]
        d.activeDisplay = "A"
        d.settings = [.init("Modifier keys", "⌃"), .init("Transition duration", "440 ms")]
        d.shortcuts = ["⌃←", "⌃→"]
        d.hotKeyFailures = ["⌃1 is taken by another app (error -9878)"]
        d.recentActivity = ["08:00:00.000 switch 1 -> 5"]
        return d
    }

    @Test func listsSpacesWithTheCurrentOneMarked() {
        let report = sample().report()
        #expect(report.contains("display A (active)\n"))
        #expect(report.contains("    1\tdesktop 1\n"))
        #expect(report.contains("  * 5\tdesktop 2\n"))
        #expect(report.contains("    600\tfull screen\n"))
    }

    @Test func alignsSettings() {
        #expect(Diagnostics.aligned([.init("Modifier keys", "⌃"), .init("Transition duration", "440 ms")])
                == "Modifier keys       : ⌃\nTransition duration : 440 ms\n")
    }

    @Test func reportsStateAndShortcuts() {
        let report = sample().report()
        #expect(report.contains("Accessibility (trackpad swipes) : granted\n"))
        #expect(report.contains("SkyLight                        : loaded\n"))
        #expect(report.contains("Registered          : ⌃←  ⌃→\n"))
        #expect(report.contains("Clash with macOS    : none\n"))
        #expect(report.contains("Taken by other apps : \n  ⌃1 is taken by another app (error -9878)\n"))
        #expect(report.contains("08:00:00.000 switch 1 -> 5\n"))
    }

    @Test func reportsAMissingSkyLight() {
        var d = sample()
        d.skyLightError = "Cannot load SkyLight.framework."
        #expect(d.report().contains("SkyLight                        : NOT loaded: Cannot load SkyLight.framework.\n"))
    }

    @Test func listsEventTapsInOrder() {
        var d = sample()
        d.swipeTaps = [
            .init(name: "SpaceJumper", pid: 42, isThisApp: true, canBlock: true, level: "session"),
            .init(name: "Karabiner-Core-Service", pid: 900, isThisApp: false, canBlock: false, level: "HID"),
        ]
        d.keyboardTaps = nil
        let report = d.report()
        #expect(report.contains("1. Karabiner-Core-Service (pid 900): listens\n2. SpaceJumper (this app) (pid 42): can block\n"))
        #expect(report.contains("## Apps that intercept the keyboard\n# Each app below sees key presses; the first one receives them first.\n"))
        #expect(report.contains("(the list of event taps is not available)\n"))
    }

    /// HID-level taps receive events before session-level ones; within a
    /// level macOS's order is kept.
    @Test func sortsTapsByDeliveryOrder() {
        let taps: [Diagnostics.EventTap] = [
            .init(name: "A", pid: 1, isThisApp: false, canBlock: true, level: "session"),
            .init(name: "B", pid: 2, isThisApp: false, canBlock: true, level: "app"),
            .init(name: "C", pid: 3, isThisApp: false, canBlock: true, level: "HID"),
            .init(name: "D", pid: 4, isThisApp: false, canBlock: true, level: "session"),
        ]
        #expect(Diagnostics.deliveryOrder(taps).map(\.name) == ["C", "A", "D", "B"])
    }

    @Test func marksDisabledTaps() {
        #expect(Diagnostics.list([.init(name: "SpaceJumper", pid: 42, isThisApp: true, canBlock: true,
                                        level: "session", enabled: false)])
                == "1. SpaceJumper (this app) (pid 42): can block (disabled)\n")
    }

    @Test func saysNoneWithoutTaps() {
        #expect(Diagnostics.list([]) == "(none)\n")
    }
}
