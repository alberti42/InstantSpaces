import CoreGraphics

/// How the desktop number is framed in the menu bar, so that it can be told
/// apart from other menu-bar items that show numbers.
public enum MenuBarFrame: String, CaseIterable, Sendable {
    /// The number alone.
    case none
    /// A thin line around the number.
    case outline
    /// A filled shape with the number cut out of it.
    case filled

    public var title: String {
        switch self {
        case .none: "None"
        case .outline: "Outline"
        case .filled: "Filled"
        }
    }
}

/// The shape of the frame. A capsule around one character is a circle.
public enum MenuBarFrameShape: String, CaseIterable, Sendable {
    case roundedRectangle
    case capsule

    public var title: String {
        switch self {
        case .roundedRectangle: "Rounded Rectangle"
        case .capsule: "Capsule"
        }
    }
}

/// The size and corner radius of a frame around text of a given width, in
/// points. Pure geometry, so it can be tested.
public struct MenuBarBadgeLayout: Equatable, Sendable {
    /// The frame's height: a little less than the 22–24 pt menu bar, as macOS
    /// draws its own badges.
    public static let height: CGFloat = 16
    /// Space between the text and the frame's sides.
    public static let padding: CGFloat = 4
    public static let roundedRectangleRadius: CGFloat = 4

    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat

    public init(textWidth: CGFloat, shape: MenuBarFrameShape) {
        height = Self.height
        let padded = (textWidth + 2 * Self.padding).rounded(.up)
        switch shape {
        case .roundedRectangle:
            width = padded
            cornerRadius = Self.roundedRectangleRadius
        case .capsule:
            // Never narrower than tall, so one character gets a circle.
            width = max(padded, Self.height)
            cornerRadius = Self.height / 2
        }
    }
}
