# Changelog

All notable changes to InstantSpaces are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Trackpad swipes inside Mission Control switch at once too. On macOS 27 this was already the case, because InstantSpaces did not recognise Mission Control there.

### Fixed

- Trackpad swipes inside App Exposé no longer switch Spaces, as in macOS.

## [0.1.0] - 2026-10-25

### Added

- Switch Spaces without the slide animation: ⌃← and ⌃→ move one Space, ⌃1 … ⌃9 go to a desktop. All shortcuts share the same modifier keys, which can be ⌃ (the default, as in macOS's Mission Control shortcuts), ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⌥⌘.
- A Settings window (⌘,) for the modifier keys, the two shortcut groups (each can be switched off), Open at Login and updates. It lists the macOS shortcuts and other apps' shortcuts that use the same keys.
- Trackpad swipes between Spaces switch instantly as well ("Switch instantly on trackpad swipes" in Settings, on by default). This needs Accessibility access, which InstantSpaces asks for on first launch; with the setting off, swipes keep macOS's animation and no access is needed.
- "Wrap around from the last Space to the first" in Settings (off by default): moving past the last Space with the arrow keys or a swipe goes to the first, and back.
- The menu bar shows the number of the current desktop.
- The menu points to Settings when a shortcut conflicts with one of macOS or another app.
- Open at Login, through a login helper registered with macOS.
- Software updates through [Sparkle](https://sparkle-project.org). InstantSpaces checks for a new version once a week; Check for Updates in the menu checks at once, and "Check for updates automatically" in Settings → General turns the weekly check on or off.

[Unreleased]: https://github.com/alberti42/InstantSpaces/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alberti42/InstantSpaces/releases/tag/v0.1.0
