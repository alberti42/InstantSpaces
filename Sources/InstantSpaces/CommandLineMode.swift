import Foundation
import InstantSpacesCore

/// Runs a command given on the command line and exits, for testing the switch
/// without hotkeys. Returns without doing anything if there is no command.
enum CommandLineMode {
    static func runIfRequested(_ arguments: [String]) {
        let command: Command
        switch Command.parse(arguments) {
        case .none: return
        case .invalid: fail(Command.usage)
        case .command(let parsed): command = parsed
        }

        let switcher: SpaceSwitcher
        do {
            switcher = try SpaceSwitcher()
        } catch {
            fail("\(error)")
        }

        switch command {
        case .list:
            list(switcher)
        case .move(let direction):
            report(switcher.move(direction), switcher)
        case .desktop(let number):
            report(switcher.goToDesktop(number), switcher)
        case .space(let space):
            guard let display = switcher.displays().first(where: { $0.spaces.contains { $0.id == space } }) else {
                fail("No display has Space \(space).")
            }
            switcher.switchTo(space, on: display)
            report(space, switcher)
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
        for prefix in ModifierPrefix.allCases {
            let clashes = switcher.clashes(with: HotKeyBinding.enabled(prefix: prefix, arrowKeys: true, desktopKeys: true))
            print("\(prefix.symbols): \(clashes.isEmpty ? "no clash with macOS shortcuts" : clashes.map(\.description).joined(separator: "; "))")
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
