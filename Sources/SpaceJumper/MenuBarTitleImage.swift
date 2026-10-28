import AppKit
import SpaceJumperCore

/// The menu-bar label as a template image of fixed width. A `Text` label changes
/// the item's width with each number ("1" is narrower than "2"; the menu bar
/// does not apply `.monospacedDigit()`), so the item moved by a few pixels on
/// every switch. All one-character labels (1–9, "F", "–") get the same width,
/// that of the widest of them, and the text is centred in it; two-digit
/// desktop numbers (10–16) get the width of "88". The item therefore keeps its
/// place between desktops 1–9, and changes width only between 9 and 10.
enum MenuBarTitleImage {
    /// The menu bar's font size (13 pt on macOS 27), with digits of equal width.
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

    /// The widest one-character labels: a digit, "F" for a full-screen Space,
    /// "–" without Spaces. "8" stands for all digits, which have equal width.
    private static let widestSingleCharacters = ["8", "F", "–"]
    /// The widest two-character label (desktops 10–16).
    private static let widestTwoCharacters = ["88"]

    /// How far the text is drawn below the image's vertical centre line. The
    /// menu bar centres the image; centred digits stood 1.5 pt higher than the
    /// menu bar's own text (measured on macOS 27.0.1: a weather item's "5°C"
    /// covered rows 19–37 of a 2× screenshot, the centred "1" rows 17–34).
    private static let baselineDrop: CGFloat = 1.5

    private static func size(fitting titles: [String]) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = titles.map { ($0 as NSString).size(withAttributes: attributes).width }.max() ?? 8
        return NSSize(width: ceil(width), height: ceil(font.ascender - font.descender))
    }

    private static let singleCharacterSize = size(fitting: widestSingleCharacters)
    private static let twoCharacterSize = size(fitting: widestTwoCharacters)

    static func size(for title: String) -> NSSize {
        title.count <= 1 ? singleCharacterSize : twoCharacterSize
    }

    /// The number in a frame: an outline, or a filled shape with the number
    /// cut out (drawn with `destinationOut`, so the menu bar shows through).
    /// The text is centred on its cap height inside the frame, and the frame
    /// has the same width for all one-character labels.
    private static func makeFramed(_ title: String, frame: MenuBarFrame, shape: MenuBarFrameShape) -> NSImage {
        let framedFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize - 1, weight: frame == .filled ? .semibold : .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: framedFont, .foregroundColor: NSColor.black]
        let widest = (title.count <= 1 ? widestSingleCharacters : widestTwoCharacters)
            .map { ($0 as NSString).size(withAttributes: attributes).width }.max() ?? 8
        let layout = MenuBarBadgeLayout(textWidth: widest, shape: shape)
        let image = NSImage(size: NSSize(width: layout.width, height: layout.height), flipped: false) { rect in
            let lineWidth: CGFloat = 1.25
            let inset = frame == .outline ? lineWidth / 2 : 0
            let radius = max(0, layout.cornerRadius - inset)
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
            NSColor.black.set()
            if frame == .filled {
                path.fill()
            } else {
                path.lineWidth = lineWidth
                path.stroke()
            }
            let text = title as NSString
            let width = text.size(withAttributes: attributes).width
            // `draw(at:)` places the bottom of the line, below the baseline by the
            // descender; the digits' baseline goes where they are centred.
            let baseline = (rect.height - framedFont.capHeight) / 2
            let origin = NSPoint(x: (rect.width - width) / 2, y: baseline + framedFont.descender)
            if frame == .filled { NSGraphicsContext.current?.compositingOperation = .destinationOut }
            text.draw(at: origin, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The number, followed by `name` (a full-screen Space's app) when given.
    static func make(_ title: String, name: String? = nil, frame: MenuBarFrame = .none,
                     shape: MenuBarFrameShape = .roundedRectangle) -> NSImage {
        let number = makeNumber(title, frame: frame, shape: shape)
        guard let name, !name.isEmpty else { return number }
        return appendingName(name, to: number)
    }

    /// Space between the number and the name.
    private static let nameGap: CGFloat = 4

    /// `number` and `name` side by side, both centred vertically. The name is
    /// in the menu bar's own font and stands as high as an unframed number.
    private static func appendingName(_ name: String, to number: NSImage) -> NSImage {
        let nameFont = NSFont.menuBarFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: NSColor.black]
        let text = name as NSString
        let textSize = text.size(withAttributes: attributes)
        let lineHeight = ceil(nameFont.ascender - nameFont.descender)
        let size = NSSize(width: number.size.width + nameGap + ceil(textSize.width),
                          height: max(number.size.height, lineHeight))
        let image = NSImage(size: size, flipped: false) { rect in
            number.draw(at: NSPoint(x: 0, y: (rect.height - number.size.height) / 2),
                        from: .zero, operation: .sourceOver, fraction: 1)
            let lineBottom = (rect.height - lineHeight) / 2
            text.draw(at: NSPoint(x: number.size.width + nameGap, y: lineBottom - nameFont.descender - baselineDrop),
                      withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func makeNumber(_ title: String, frame: MenuBarFrame, shape: MenuBarFrameShape) -> NSImage {
        if frame != .none { return makeFramed(title, frame: frame, shape: shape) }
        let image = NSImage(size: size(for: title), flipped: false) { rect in
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let text = title as NSString
            let width = text.size(withAttributes: attributes).width
            text.draw(at: NSPoint(x: (rect.width - width) / 2, y: -font.descender - baselineDrop), withAttributes: attributes)
            return true
        }
        // The menu bar tints template images for its appearance.
        image.isTemplate = true
        return image
    }
}
