import AppKit

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

    static func make(_ title: String) -> NSImage {
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
