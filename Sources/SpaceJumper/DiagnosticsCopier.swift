import AppKit
import OSLog
import SpaceJumperCore

/// Copy Diagnostics… in the menu, as in Volume Control: an alert says what
/// will happen, the report goes to the clipboard, and a second alert offers
/// the GitHub issues page. Nothing is sent anywhere.
@MainActor
enum DiagnosticsCopier {
    private static let issues = URL(string: "https://github.com/alberti42/SpaceJumper/issues")!

    static func run(model: AppModel) {
        AppActivation.activate()
        let ask = NSAlert()
        ask.messageText = "Copy Diagnostics"
        ask.informativeText = "SpaceJumper will copy a diagnostics report to your clipboard, replacing its current contents.\n\nNothing is sent over the Internet: it is plain text you can read and edit before sharing, for example in a GitHub issue."
        ask.addButton(withTitle: "Copy to Clipboard")
        ask.addButton(withTitle: "Cancel")
        guard ask.runModal() == .alertFirstButtonReturn else { return }

        var diagnostics = model.diagnostics()
        let info = Bundle.main.infoDictionary ?? [:]
        diagnostics.version = "\(info["CFBundleShortVersionString"] as? String ?? "?") (build \(info["CFBundleVersion"] as? String ?? "?"))"
        diagnostics.macOS = ProcessInfo.processInfo.operatingSystemVersionString
        diagnostics.macModel = hardwareModel()
        diagnostics.systemIntegrityProtection = systemIntegrityProtection()
        diagnostics.recentActivity = recentActivity()
        if let taps = eventTaps() {
            diagnostics.swipeTaps = taps.filter { $0.events & swipeEvents != 0 }.map(\.tap)
            diagnostics.keyboardTaps = taps.filter { $0.events & keyEvents != 0 }.map(\.tap)
        } else {
            diagnostics.swipeTaps = nil
            diagnostics.keyboardTaps = nil
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics.report(), forType: .string)

        let done = NSAlert()
        done.messageText = "Diagnostics Copied"
        done.informativeText = "The report is on your clipboard. Paste it into your GitHub issue."
        done.addButton(withTitle: "Visit GitHub Issues Page")
        done.addButton(withTitle: "Done")
        if done.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(issues)
        }
    }

    /// `hw.model`, e.g. "Mac15,9".
    private static func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "?" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "?" }
        return String(cString: buffer)
    }

    /// "enabled" or "disabled", from `csrutil status`.
    private static func systemIntegrityProtection() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
        process.arguments = ["status"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard (try? process.run()) != nil else { return "?" }
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        // "System Integrity Protection status: enabled."
        guard let status = output.split(separator: ":").last else { return "?" }
        return status.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    }

    /// Trackpad gesture (29) and Dock control (30) events, which the swipe tap takes.
    private static let swipeEvents: CGEventMask = 1 << 29 | 1 << 30
    /// Key down and key up.
    private static let keyEvents: CGEventMask = 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue

    /// The event taps with the events they take, in the order macOS lists
    /// them (`CGGetEventTapList`); nil if the list is not available. Disabled
    /// taps are included: a disabled SpaceJumper tap explains swipes that do
    /// not work.
    private static func eventTaps() -> [(tap: Diagnostics.EventTap, events: CGEventMask)]? {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return nil }
        var list = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &list, &count) == .success else { return nil }
        let own = getpid()
        return list.prefix(Int(count)).map { info in
            let level = switch info.tapPoint {
            case .cghidEventTap: "HID"
            case .cgSessionEventTap: "session"
            default: "app"
            }
            let tap = Diagnostics.EventTap(name: processName(info.tappingProcess), pid: info.tappingProcess,
                                           isThisApp: info.tappingProcess == own,
                                           canBlock: info.options != .listenOnly, level: level,
                                           enabled: info.enabled)
            return (tap, info.eventsOfInterest)
        }
    }

    /// The app's name, or the executable's name for a process that is not an app.
    private static func processName(_ pid: pid_t) -> String {
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: 1024)
        return proc_name(pid, &buffer, UInt32(buffer.count)) > 0 ? String(cString: buffer) : "?"
    }

    /// The last 50 messages of SpaceJumper's own log from the last 30 minutes,
    /// oldest first. Reading the own process's log needs no permission.
    private static func recentActivity() -> [String] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return [] }
        let start = store.position(date: Date().addingTimeInterval(-30 * 60))
        let predicate = NSPredicate(format: "subsystem == %@", "io.alberti42.SpaceJumper")
        guard let entries = try? store.getEntries(at: start, matching: predicate) else { return [] }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "HH:mm:ss.SSS"
        return entries.suffix(50).map { "\(format.string(from: $0.date)) \($0.composedMessage)" }
    }
}
