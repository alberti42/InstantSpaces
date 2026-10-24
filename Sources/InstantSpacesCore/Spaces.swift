import Foundation

/// One Space, as `SLSCopyManagedDisplaySpaces` lists it.
public struct Space: Equatable, Sendable {
    /// `ManagedSpaceID`.
    public let id: UInt64
    /// `type`: 0 for a user desktop, 4 for a full-screen Space.
    public let type: Int

    public init(id: UInt64, type: Int) {
        self.id = id
        self.type = type
    }

    public var isDesktop: Bool { type == 0 }
}

/// The Spaces of one display, in Mission Control order.
public struct DisplaySpaces: Equatable, Sendable {
    /// `Display Identifier`: a UUID, or "Main" when displays share Spaces.
    public let identifier: String
    public let current: UInt64
    public let spaces: [Space]

    public init(identifier: String, current: UInt64, spaces: [Space]) {
        self.identifier = identifier
        self.current = current
        self.spaces = spaces
    }

    /// Parses the result of `SLSCopyManagedDisplaySpaces`. Entries without a
    /// display identifier or a current Space are skipped.
    public static func parse(_ displays: [[String: Any]]) -> [DisplaySpaces] {
        displays.compactMap { display in
            guard let identifier = display["Display Identifier"] as? String,
                  let currentSpace = display["Current Space"] as? [String: Any],
                  let current = spaceID(currentSpace),
                  let list = display["Spaces"] as? [[String: Any]]
            else { return nil }
            let spaces = list.compactMap { entry -> Space? in
                guard let id = spaceID(entry) else { return nil }
                return Space(id: id, type: (entry["type"] as? NSNumber)?.intValue ?? 0)
            }
            return DisplaySpaces(identifier: identifier, current: current, spaces: spaces)
        }
    }

    private static func spaceID(_ entry: [String: Any]) -> UInt64? {
        (entry["ManagedSpaceID"] as? NSNumber)?.uint64Value
    }
}

public enum Direction: String, Sendable {
    case left, right
}

/// Which Space a shortcut leads to. Pure functions, so they can be tested.
public enum SpaceNavigator {
    /// The neighbour of `current` in `spaces`, counting full-screen Spaces as
    /// macOS does. Nil at either end: macOS does not wrap around.
    public static func neighbour(of current: UInt64, in spaces: [Space], direction: Direction) -> UInt64? {
        guard let index = spaces.firstIndex(where: { $0.id == current }) else { return nil }
        let target = direction == .left ? index - 1 : index + 1
        return spaces.indices.contains(target) ? spaces[target].id : nil
    }

    /// User desktop `number` (1-based). Full-screen Spaces are not numbered, as
    /// in Mission Control's "Desktop N" names.
    public static func desktop(_ number: Int, in spaces: [Space]) -> UInt64? {
        let desktops = spaces.filter(\.isDesktop)
        guard number >= 1, number <= desktops.count else { return nil }
        return desktops[number - 1].id
    }

    /// The 1-based desktop number of `space`, or nil for a full-screen Space.
    public static func desktopNumber(of space: UInt64, in spaces: [Space]) -> Int? {
        spaces.filter(\.isDesktop).firstIndex(where: { $0.id == space }).map { $0 + 1 }
    }
}
