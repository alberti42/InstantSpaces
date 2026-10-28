import Foundation

/// A shortcut that jumps to an app: the modifier prefix followed by `letter`
/// switches to the Space of the app's frontmost window and brings the app
/// forward, or opens it.
public struct AppShortcut: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// One of `letters`.
    public var letter: Character
    public let bundleIdentifier: String
    /// The app's name when it was added, for the Settings window and the log.
    public let name: String

    public var id: String { bundleIdentifier }

    public init(letter: Character, bundleIdentifier: String, name: String) {
        self.letter = letter
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    /// The letters an app shortcut can use.
    public static let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    /// The first letter of `name` that no other shortcut uses, then the first
    /// free letter of the alphabet; nil when all are taken.
    public static func suggestedLetter(for name: String, taken: [AppShortcut]) -> Character? {
        let used = Set(taken.map(\.letter))
        let fromName = name.uppercased().filter { letters.contains($0) }
        return (fromName + letters).first { !used.contains($0) }
    }

    /// Sets the letter of the shortcut for `bundleIdentifier`. A shortcut that
    /// already uses the letter gets the old one, so no two share a letter.
    public static func assign(_ letter: Character, to bundleIdentifier: String,
                              in shortcuts: [AppShortcut]) -> [AppShortcut] {
        guard let old = shortcuts.first(where: { $0.bundleIdentifier == bundleIdentifier })?.letter else { return shortcuts }
        return shortcuts.map { shortcut in
            var shortcut = shortcut
            if shortcut.bundleIdentifier == bundleIdentifier {
                shortcut.letter = letter
            } else if shortcut.letter == letter {
                shortcut.letter = old
            }
            return shortcut
        }
    }

    private enum CodingKeys: String, CodingKey { case letter, bundleIdentifier, name }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let letter = try container.decode(String.self, forKey: .letter).first else {
            throw DecodingError.dataCorruptedError(forKey: .letter, in: container, debugDescription: "empty letter")
        }
        self.letter = letter
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(letter), forKey: .letter)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(name, forKey: .name)
    }
}
