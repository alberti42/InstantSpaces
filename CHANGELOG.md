# Changelog

All notable changes to InstantSpaces are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Switch Spaces without the slide animation: ⌃← and ⌃→ move one Space, ⌃1 … ⌃9 go to a desktop. All shortcuts share the same modifier keys, which can be ⌃ (the default, as in macOS's Mission Control shortcuts), ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⌥⌘.
- A Settings window (⌘,) for the modifier keys, the two shortcut groups (each can be switched off), Open at Login and updates. It lists the macOS shortcuts and other apps' shortcuts that use the same keys.
- The menu bar shows the number of the current desktop.
- The menu points to Settings when a shortcut conflicts with one of macOS or another app.
- Open at Login, through a login helper registered with macOS.
- Software updates through [Sparkle](https://sparkle-project.org). InstantSpaces checks for a new version once a week; Check for Updates in the menu checks at once, and "Check for updates automatically" in Settings → General turns the weekly check on or off.

[Unreleased]: https://github.com/alberti42/InstantSpaces/commits/main
