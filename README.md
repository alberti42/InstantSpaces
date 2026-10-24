<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
# InstantSpaces

**A menu-bar app for macOS that switches between Spaces without the slide animation.**

Free and open source (GPL-3.0). Requires macOS 26 or later. There is no release
yet; see [Building from source](#building-from-source).

macOS has no setting to turn off the animation that plays when you switch
Spaces. "Reduce motion" replaces the slide with a cross-fade, which is still an
animation. InstantSpaces switches with no animation at all: the new Space
appears at once.

---

## Table of Contents

- [Features](#features)
- [Status](#status)
- [Installation](#installation)
- [Turn off the system shortcuts](#turn-off-the-system-shortcuts)
- [Permissions and privacy](#permissions-and-privacy)
- [How it works](#how-it-works)
- [Building from source](#building-from-source)
- [Credits](#credits)
- [License](#license)

---

## Features

| Shortcut | Action |
|---|---|
| ⌃← / ⌃→ | Move one Space left / right |
| ⌃1 … ⌃9 | Go to desktop 1 … 9 |

All shortcuts share the same modifier keys: ⌃ (the default, as in macOS's own
Mission Control shortcuts), ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⌥⌘, chosen in Settings.

- **Trackpad swipes** between Spaces switch instantly too (on by default; can be
  switched off in Settings). This needs Accessibility access; see
  [Permissions and privacy](#permissions-and-privacy).
- **Menu-bar item** showing the number of the current desktop, or "F" on a
  full-screen Space.
- **Settings window** (Settings… in the menu, ⌘,): the modifier keys, the two
  shortcut groups (arrows and numbers), each of which can be switched off, Open
  at Login and updates. It lists the shortcuts that macOS or another app
  already uses with the same keys.
- **Desktop numbers** count desktops as Mission Control names them ("Desktop
  1", "Desktop 2", …); full-screen Spaces are skipped. ⌃← and ⌃→ include
  full-screen Spaces, as macOS does, and stop at the first and last Space.
- **Wrap around** (off by default): ⌃← ⌃→ and trackpad swipes go from the last
  Space to the first and back.
- **Several displays**: the shortcuts act on the display with the active menu bar.
- **Open at login**, through a login helper registered with macOS.
- **Updates** through [Sparkle](https://sparkle-project.org): InstantSpaces
  checks for a new version once a week, or when you choose Check for Updates in
  its menu.

## Status

InstantSpaces is early work. It relies on private macOS interfaces (see
[How it works](#how-it-works)), which Apple can change in any update.

Tested so far on macOS 27.0.1 only, with System Integrity Protection disabled.
Not yet tested:

- macOS 26, and any Mac with System Integrity Protection enabled.
- Switching to full-screen Spaces.
- More than one display.
- Trackpad swipes: the direction on real hardware, with and without natural
  scrolling, and Karabiner-Elements running.
- Whether the Dock's own record of the current Space (used by Mission Control
  and the trackpad swipe) stays correct after InstantSpaces switches.

## Installation

1. Build the app (see [Building from source](#building-from-source)) and move
   `build/InstantSpaces.app` to the Applications folder.
2. Open it. Its number appears in the menu bar.
3. Turn off macOS's shortcuts that use the same keys (next section).
4. To start InstantSpaces when you log in, turn on Open at Login in its Settings.

## Turn off the system shortcuts

macOS binds ⌃← and ⌃→ to its own animated switch by default. If both
InstantSpaces and macOS react to the same key, both switch. With the default
modifier ⌃, turn them off in System Settings → Keyboard → Keyboard Shortcuts →
Mission Control: untick "Move left a space" and "Move right a space", and
"Switch to Desktop 1 … 9" if you have turned those on (they are off by default).

The Settings window of InstantSpaces lists the switched-on macOS shortcuts
that its keys would also trigger, with the name System Settings uses where
InstantSpaces knows it, and has a button that opens Keyboard settings.
Alternatively, choose other modifier keys.

For arrow keys, macOS stores ⌃← and fn⌃← the same way, so InstantSpaces cannot
tell them apart. It counts only the Mission Control shortcuts, which macOS
defines with plain arrows; the window-tiling shortcuts (fn⌃←, fn⌃→) do not
react to ⌃← and ⌃→. A macOS shortcut that you rebind yourself to a plain arrow
is not detected.

## Permissions and privacy

- The keyboard shortcuts need no permission: they are registered with
  `RegisterEventHotKey`, which does not require Accessibility access.
- Instant trackpad swipes need Accessibility access. InstantSpaces reads the
  trackpad's swipe events before the Dock does, drops them and switches
  instead; macOS allows that only to apps with Accessibility access. On first
  launch InstantSpaces asks for it; Settings shows whether it has it. Without
  it, or with "Switch instantly on trackpad swipes" off, swipes keep macOS's
  animation. InstantSpaces only looks at the trackpad's Dock swipe events and
  does not read the keyboard.
- InstantSpaces connects to the network only for updates: it downloads the
  update feed (`Releases/appcast.xml` in this repository) from GitHub, and, when
  you install an update, `InstantSpaces.zip` from GitHub Releases. Sparkle sends
  no system profile; the requests carry the names and versions of InstantSpaces
  and Sparkle in the User-Agent header. Turn off "Check for updates
  automatically" in Settings → General to check only when you choose Check for
  Updates.
- InstantSpaces collects no data.
- Its settings (modifier keys, shortcut groups, swipes, wrapping) are stored in
  `~/Library/Preferences/io.alberti42.InstantSpaces.plist`.

## How it works

### Keyboard shortcuts

The animation is drawn by the Dock. When you switch Spaces, the Dock shows both
Spaces, slides them across the screen, and then tells WindowServer to make the
new Space current. WindowServer makes that change at once.

InstantSpaces sends WindowServer the same three requests the Dock sends,
without the slide: show the new Space, make it current, hide the other Spaces.
It uses SkyLight's bridged window-management operations
(`SLSBridgedShowSpacesOperation`, `SLSBridgedManagedDisplaySetCurrentSpaceOperation`,
`SLSBridgedHideSpacesOperation`). SkyLight is the private framework through
which apps and the Dock talk to WindowServer.

The plain SkyLight functions are not enough. Called from an app other than the
Dock, `SLSManagedDisplaySetCurrentSpace` changes the Space, but
`SLSShowSpaces` and `SLSHideSpaces` are refused, so the windows of both Spaces
stay on screen. The bridged operations are accepted.

### Trackpad swipes

A swipe between Spaces reaches the Dock as a series of "Dock swipe" events:
began, changed (with the distance moved), ended. InstantSpaces watches them
with an event tap placed before the Dock. It drops the began event, so the
Dock never starts its slide; at the first changed event that moved, it
switches one Space in that direction, as the keyboard shortcuts do. From macOS
27 on, the ended event is passed on with its motion set to zero, because the
Dock needs it to finish the gesture. Swipes that begin while Mission Control or
App Exposé is open are left to the Dock.

## Building from source

Requires the Swift 6.2 toolchain or later (Xcode or the Command Line Tools).
No Xcode project is involved.

```sh
make app     # build/InstantSpaces.app, signed ad hoc
make run     # build and open it
make test    # run the tests
```

`ARCHS=universal make app` builds for Apple silicon and Intel; the default is
this Mac's architecture. To sign with a Developer ID, set `SIGN_IDENTITY`:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

To use your own signing identity, also change the bundle identifiers
`io.alberti42.InstantSpaces` and `io.alberti42.InstantSpaces.LoginHelper` in
`Resources/Info.plist`, `Resources/LoginHelper-Info.plist`,
`Sources/LoginHelper/main.swift` and `Sources/InstantSpaces/LoginItem.swift`.
To publish your own updates, set `SUFeedURL` (your appcast) and
`SUPublicEDKey` (your EdDSA public key) in `Resources/Info.plist`; otherwise
your build offers the updates published in this repository.

The executable also takes commands, which switch once and exit:

```sh
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --list            # displays and Spaces
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --move right
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --desktop 2
```

## Credits

- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) by
  jurplel skips the animation by sending the Dock a trackpad swipe with a very
  high velocity. InstantSpaces intercepts swipes following its findings on the
  Dock's swipe events: the event fields, the handling of the ended event on
  macOS 27, and how to tell when Mission Control is open.
- [yabai](https://github.com/asmvik/yabai) by asmvik uses the bridged
  operations to move windows between Spaces
  ([#2788](https://github.com/asmvik/yabai/issues/2788)); InstantSpaces looks up
  SkyLight's private perform function the same way.

The app was created with AI assistance (Claude).

## License

[GNU General Public License v3.0](LICENSE)
