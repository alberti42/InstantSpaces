/// The text of the menu-bar item and of the first line of the menu.
public struct SpaceStatus: Equatable, Sendable {
    /// The Space's number, "F" on a full-screen Space when only desktops are
    /// numbered, "–" without Spaces.
    public let title: String
    public let line: String
    /// Mission Control's name of a full-screen Space (`Space.missionControlName`);
    /// nil on a desktop.
    public let name: String?

    public init(title: String, line: String, name: String? = nil) {
        self.title = title
        self.line = line
        self.name = name
    }

    public static func make(current: UInt64, spaces: [Space], numbering: SpaceNumbering,
                            appName: (Int32) -> String? = { _ in nil }) -> SpaceStatus {
        let name = spaces.first(where: { $0.id == current })?.missionControlName(appName: appName)
        let named = name.map { ": \($0)" } ?? ""
        if numbering == .allSpaces, let number = SpaceNavigator.number(of: current, in: spaces, numbering: numbering) {
            let kind = spaces[number - 1].isDesktop ? "" : ", full screen"
            return SpaceStatus(title: "\(number)", line: "Space \(number) of \(spaces.count)\(kind)\(named)", name: name)
        }
        if let number = SpaceNavigator.desktopNumber(of: current, in: spaces) {
            let desktops = spaces.filter(\.isDesktop).count
            return SpaceStatus(title: "\(number)", line: "Desktop \(number) of \(desktops)")
        }
        if spaces.contains(where: { $0.id == current }) {
            return SpaceStatus(title: "F", line: "Full-screen Space\(named)", name: name)
        }
        return unavailable("No Spaces found.")
    }

    public static func unavailable(_ reason: String) -> SpaceStatus {
        SpaceStatus(title: "–", line: reason)
    }
}
