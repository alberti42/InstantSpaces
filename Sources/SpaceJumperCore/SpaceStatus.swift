/// The text of the menu-bar item and of the first line of the menu.
public struct SpaceStatus: Equatable, Sendable {
    /// The desktop number, "F" on a full-screen Space, "–" without Spaces.
    public let title: String
    public let line: String

    public init(title: String, line: String) {
        self.title = title
        self.line = line
    }

    public static func make(current: UInt64, spaces: [Space]) -> SpaceStatus {
        if let number = SpaceNavigator.desktopNumber(of: current, in: spaces) {
            let desktops = spaces.filter(\.isDesktop).count
            return SpaceStatus(title: "\(number)", line: "Desktop \(number) of \(desktops)")
        }
        if spaces.contains(where: { $0.id == current }) {
            return SpaceStatus(title: "F", line: "Full-screen Space")
        }
        return unavailable("No Spaces found.")
    }

    public static func unavailable(_ reason: String) -> SpaceStatus {
        SpaceStatus(title: "–", line: reason)
    }
}
