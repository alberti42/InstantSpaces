import Foundation
import InstantSpacesCore

/// Runs a command given on the command line and exits, for testing the switch
/// without hotkeys. Returns without doing anything if there is no command.
enum CommandLineMode {
    static let usage = """
        usage: InstantSpaces [--list | --move left|right | --desktop N | --space ID]
        """

    static func runIfRequested(_ arguments: [String]) {
        guard let command = arguments.first, command.hasPrefix("--") else { return }
        let value = arguments.dropFirst().first

        let switcher: SpaceSwitcher
        do {
            switcher = try SpaceSwitcher()
        } catch {
            fail("\(error)")
        }

        switch command {
        case "--list":
            list(switcher)
        case "--move":
            guard let value, let direction = Direction(rawValue: value) else { fail(usage) }
            report(switcher.move(direction), switcher)
        case "--desktop":
            guard let value, let number = Int(value) else { fail(usage) }
            report(switcher.goToDesktop(number), switcher)
        case "--space":
            guard let value, let space = UInt64(value), let display = switcher.displays().first(where: {
                $0.spaces.contains { $0.id == space }
            }) else { fail("No display has Space \(value ?? "").") }
            switcher.switchTo(space, on: display)
            report(space, switcher)
        default:
            fail(usage)
        }
        exit(0)
    }

    private static func list(_ switcher: SpaceSwitcher) {
        let active = switcher.activeDisplay()?.identifier
        for display in switcher.displays() {
            print("display \(display.identifier)\(display.identifier == active ? " (active)" : "")")
            for space in display.spaces {
                let number = SpaceNavigator.desktopNumber(of: space.id, in: display.spaces)
                let name = number.map { "desktop \($0)" } ?? "full screen"
                print("  \(space.id == display.current ? "*" : " ") \(space.id)\t\(name)")
            }
        }
        for hotKey in SystemHotKey.allCases {
            print("system shortcut \(hotKey): \(switcher.isSystemHotKeyEnabled(hotKey) ? "on" : "off")")
        }
    }

    /// Waits for the asynchronous operations, then prints what WindowServer reports.
    private static func report(_ target: UInt64?, _ switcher: SpaceSwitcher) {
        guard let target else { fail("No Space in that direction or with that number.") }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let current = switcher.activeDisplay()?.current
        print("switched to \(target); WindowServer reports \(current.map(String.init) ?? "nothing")")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
