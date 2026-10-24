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
| ⌃⌘1 … ⌃⌘9 | Go to desktop 1 … 9 |

- **Menu-bar item** showing the number of the current desktop, or "F" on a
  full-screen Space.
- **Two shortcut groups** (arrows and numbers), each of which can be switched off in the menu.
- **Desktop numbers** count desktops as Mission Control names them ("Desktop
  1", "Desktop 2", …); full-screen Spaces are skipped. ⌃← and ⌃→ include
  full-screen Spaces, as macOS does, and stop at the first and last Space.
- **Several displays**: the shortcuts act on the display with the active menu bar.
- **Open at login**, through a login helper registered with macOS.

## Status

InstantSpaces is early work. It relies on private macOS interfaces (see
[How it works](#how-it-works)), which Apple can change in any update.

Tested so far on macOS 27.0.1 only, with System Integrity Protection disabled.
Not yet tested:

- macOS 26, and any Mac with System Integrity Protection enabled.
- Switching to full-screen Spaces.
- More than one display.
- Whether the Dock's own record of the current Space (used by Mission Control
  and the trackpad swipe) stays correct after InstantSpaces switches.

## Installation

1. Build the app (see [Building from source](#building-from-source)) and move
   `build/InstantSpaces.app` to the Applications folder.
2. Open it. Its number appears in the menu bar.
3. Turn off macOS's own ⌃← and ⌃→ shortcuts (next section).
4. To start InstantSpaces when you log in, choose Open at Login in its menu.

## Turn off the system shortcuts

macOS binds ⌃← and ⌃→ to its own animated switch by default. If both
InstantSpaces and macOS react to the same key, both switch. Turn them off in
System Settings → Keyboard → Keyboard Shortcuts → Mission Control: untick "Move
left a space" and "Move right a space". The InstantSpaces menu reports when they
are still on and has a button that opens Keyboard settings.

"Switch to Desktop 1 … 9" (⌃1 … ⌃9) is off by default in macOS and does not
conflict with ⌃⌘1 … ⌃⌘9.

## Permissions and privacy

- InstantSpaces needs no permission. Its shortcuts are registered with
  `RegisterEventHotKey`, which does not require Accessibility access.
- It makes no network connections and collects no data.
- Its two settings (`arrowKeysEnabled`, `desktopKeysEnabled`) are stored in
  `~/Library/Preferences/io.alberti42.InstantSpaces.plist`.

## How it works

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

The executable also takes commands, which switch once and exit:

```sh
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --list            # displays and Spaces
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --move right
build/InstantSpaces.app/Contents/MacOS/InstantSpaces --desktop 2
```

## Credits

- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) by
  jurplel skips the animation by sending the Dock a trackpad swipe with a very
  high velocity. Its notes on the Dock's swipe events are the basis for gesture
  support planned in InstantSpaces.
- [yabai](https://github.com/asmvik/yabai) by asmvik uses the bridged
  operations to move windows between Spaces
  ([#2788](https://github.com/asmvik/yabai/issues/2788)); InstantSpaces looks up
  SkyLight's private perform function the same way.

The app was created with AI assistance (Claude).

## License

[GNU General Public License v3.0](LICENSE)
