import AppKit

/// The menu-bar label as a template image of fixed size. A `Text` label changes
/// the item's width with each number ("1" is narrower than "2"; the menu bar
/// does not apply `.monospacedDigit()`), so the item moved by a few pixels on
/// every switch. The image is as wide as the widest label and the text is
/// centred in it.
enum MenuBarTitleImage {
    /// The menu bar's font size (13 pt on macOS 27), with digits of equal width.
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

    /// The widest labels: two-digit desktop numbers (up to 16 desktops), "F"
    /// for a full-screen Space, "–" without Spaces.
    private static let widestTitles = ["88", "F", "–"]

    static let size: NSSize = {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = widestTitles.map { ($0 as NSString).size(withAttributes: attributes).width }.max() ?? 16
        return NSSize(width: ceil(width), height: ceil(font.ascender - font.descender))
    }()

    static func make(_ title: String) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let text = title as NSString
            let width = text.size(withAttributes: attributes).width
            text.draw(at: NSPoint(x: (rect.width - width) / 2, y: -font.descender), withAttributes: attributes)
            return true
        }
        // The menu bar tints template images for its appearance.
        image.isTemplate = true
        return image
    }
}
