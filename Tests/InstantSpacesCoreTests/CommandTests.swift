import Testing
@testable import InstantSpacesCore

@Suite struct CommandTests {
    @Test func noArgumentsStartTheApp() {
        #expect(Command.parse([]) == .none)
    }

    /// Older systems pass "-psn_0_12345" to apps opened from the Finder.
    @Test func processSerialNumberStartsTheApp() {
        #expect(Command.parse(["-psn_0_12345"]) == .none)
    }

    @Test func appFlagsStartTheApp() {
        #expect(Command.parse(["--show-settings"]) == .none)
    }

    @Test func parsesEachCommand() {
        #expect(Command.parse(["--list"]) == .command(.list))
        #expect(Command.parse(["--move", "left"]) == .command(.move(.left)))
        #expect(Command.parse(["--move", "right"]) == .command(.move(.right)))
        #expect(Command.parse(["--desktop", "2"]) == .command(.desktop(2)))
        #expect(Command.parse(["--space", "475"]) == .command(.space(475)))
    }

    @Test(arguments: [
        ["--move"], ["--move", "up"], ["--desktop"], ["--desktop", "two"], ["--desktop", "0"],
        ["--space", "-1"], ["--space", "abc"], ["--frobnicate"],
    ])
    func rejectsInvalidArguments(_ arguments: [String]) {
        #expect(Command.parse(arguments) == .invalid)
    }
}
