# SpaceJumper

[![notarized download](https://img.shields.io/github/actions/workflow/status/alberti42/SpaceJumper/verify-release.yml?label=notarized%20download&logo=apple)](https://github.com/alberti42/SpaceJumper/actions/workflows/verify-release.yml)
[![build](https://img.shields.io/github/actions/workflow/status/alberti42/SpaceJumper/build.yml?branch=main&label=build)](https://github.com/alberti42/SpaceJumper/actions/workflows/build.yml)

**A menu-bar app for macOS that switches between Spaces without the slide animation, or with a slide as long as you choose.**

Ever wished you could jump between your Mac's Spaces like a starship jumping to
hyperspace? SpaceJumper switches Spaces instantly, without macOS's slide. And
if you'd like to see the jump, you can set how long it takes.

**[Download SpaceJumper.zip](https://github.com/alberti42/SpaceJumper/releases/latest/download/SpaceJumper.zip)** (latest release, signed and notarized). See [Installation](#installation).

Free and open source (GPL-3.0). Requires macOS 26 or later; runs natively on
Apple silicon and Intel Macs.

macOS has no setting to turn off the animation that plays when you switch
Spaces. "Reduce motion" replaces the slide with a cross-fade, which is still an
animation. SpaceJumper switches with no animation at all: the new Space
appears at once. If you prefer a slide, SpaceJumper draws its own, as long as
you set it.

SpaceJumper was called InstantSpaces up to version 0.1.1; see
[Moving from InstantSpaces](#moving-from-instantspaces).

---

## Table of Contents

- [Features](#features)
- [Status](#status)
- [Installation](#installation)
- [Turn off the system shortcuts](#turn-off-the-system-shortcuts)
- [Permissions and privacy](#permissions-and-privacy)
- [Troubleshooting](#troubleshooting)
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
  full-screen Space. It can have a frame, to tell it apart from other numbers
  in the menu bar: an outline or a filled shape with the number cut out, as a
  rounded rectangle or a capsule.
- **Settings window** (Settings… in the menu, ⌘,): the modifier keys, the two
  shortcut groups (arrows and numbers), each of which can be switched off, Open
  at Login and updates. It lists the shortcuts that macOS or another app
  already uses with the same keys.
- **Desktop numbers** count desktops as Mission Control names them ("Desktop
  1", "Desktop 2", …); full-screen Spaces are skipped. ⌃← and ⌃→ include
  full-screen Spaces, as macOS does, and stop at the first and last Space.
- **Slide animation** (off by default): a slide of your chosen length, 0 to
  500 ms in 10 ms steps, for the shortcuts and swipes. SpaceJumper draws it
  itself, so ⌃1 … ⌃9 slide straight to the desktop.
- **Wrap around** (off by default): ⌃← ⌃→ and trackpad swipes go from the last
  Space to the first and back.
- **Several displays**: the shortcuts act on the display with the active menu bar.
- **Open at login**, through a login helper registered with macOS.
- **Updates** through [Sparkle](https://sparkle-project.org): SpaceJumper
  checks for a new version once a week, or when you choose Check for Updates in
  its menu.

## Status

SpaceJumper is early work. It relies on private macOS interfaces (see
[How it works](#how-it-works)), which Apple can change in any update.

Tested on one Mac with macOS 27.0.1 and System Integrity Protection disabled,
with Karabiner-Elements running: the keyboard shortcuts, trackpad swipes in
both directions with natural scrolling on and off (the direction follows
macOS's), trackpad swipes inside Mission Control and App Exposé, and switching
to and from full-screen Spaces. After each switch the Dock records the new
Space, and Mission Control shows it.

Not yet tested:

- macOS 26, and any Mac with System Integrity Protection enabled. SpaceJumper
  declares macOS 26 as its minimum, but no one has run it there yet. If you
  find a problem on macOS 26, please open an
  [issue](https://github.com/alberti42/SpaceJumper/issues).
- More than one display.

Known issue, not yet reproduced: once, after a long session of tests, the menu
bar, set to hide automatically, no longer appeared when the pointer reached the
top of the screen. Quitting SpaceJumper and restarting the Dock did not bring
it back; logging out did. Whether SpaceJumper caused it is not known.

## Installation

1. Download [`SpaceJumper.zip`](https://github.com/alberti42/SpaceJumper/releases/latest/download/SpaceJumper.zip)
   from the [latest release](https://github.com/alberti42/SpaceJumper/releases/latest).
2. Unzip it and move `SpaceJumper.app` to the Applications folder.
3. Open it. The number of the current desktop appears in the menu bar.
4. macOS asks whether SpaceJumper may use Accessibility. Allow it for instant
   trackpad swipes (System Settings → Privacy & Security → Accessibility); the
   keyboard shortcuts work without it. See
   [Permissions and privacy](#permissions-and-privacy).
5. Turn off macOS's shortcuts that use the same keys (next section).
6. To start SpaceJumper when you log in, turn on Open at Login in its Settings.

The app is signed with a Developer ID and notarized by Apple. To check where a
downloaded ZIP was built:

```sh
gh attestation verify SpaceJumper.zip --repo alberti42/SpaceJumper
```

### Moving from InstantSpaces

SpaceJumper was called InstantSpaces up to version 0.1.1. The two apps have
different bundle identifiers, so InstantSpaces cannot update itself to
SpaceJumper; it shows the new release with a link to this page instead.

1. Quit InstantSpaces and move `InstantSpaces.app` to the Trash. This also
   removes its login item.
2. Install SpaceJumper as above. On first launch it copies the InstantSpaces
   settings: modifier keys, shortcut groups, swipes, wrap-around and updates.
3. Allow Accessibility access for SpaceJumper, and turn on Open at Login again
   if you used it. You can remove InstantSpaces from System Settings → Privacy &
   Security → Accessibility.

## Turn off the system shortcuts

macOS binds ⌃← and ⌃→ to its own animated switch by default. If both
SpaceJumper and macOS react to the same key, both switch. With the default
modifier ⌃, turn them off in System Settings → Keyboard → Keyboard Shortcuts →
Mission Control: untick "Move left a space" and "Move right a space", and
"Switch to Desktop 1 … 9" if you have turned those on (they are off by default).

The Settings window of SpaceJumper lists the switched-on macOS shortcuts
that its keys would also trigger, with the name System Settings uses where
SpaceJumper knows it, and has a button that opens Keyboard settings.
Alternatively, choose other modifier keys.

For arrow keys, macOS stores ⌃← and fn⌃← the same way, so SpaceJumper cannot
tell them apart. It counts only the Mission Control shortcuts, which macOS
defines with plain arrows; the window-tiling shortcuts (fn⌃←, fn⌃→) do not
react to ⌃← and ⌃→. A macOS shortcut that you rebind yourself to a plain arrow
is not detected.

## Permissions and privacy

- The keyboard shortcuts need no permission: they are registered with
  `RegisterEventHotKey`, which does not require Accessibility access.
- Instant trackpad swipes need Accessibility access. SpaceJumper reads the
  trackpad's swipe events before the Dock does, drops them and switches
  instead; macOS allows that only to apps with Accessibility access. On first
  launch SpaceJumper asks for it; Settings shows whether it has it. Without
  it, or with "Switch instantly on trackpad swipes" off, swipes keep macOS's
  animation. SpaceJumper only looks at the trackpad's Dock swipe events and,
  when a swipe begins, at the Dock's accessibility elements to tell whether
  App Exposé is open. It does not read the keyboard.
- SpaceJumper connects to the network only for updates: it downloads the
  update feed (`Releases/appcast.xml` in this repository) from GitHub, and, when
  you install an update, `SpaceJumper.zip` from GitHub Releases. Sparkle sends
  no system profile; the requests carry the names and versions of SpaceJumper
  and Sparkle in the User-Agent header. Turn off "Check for updates
  automatically" in Settings → General to check only when you choose Check for
  Updates.
- SpaceJumper collects no data.
- Its settings (modifier keys, shortcut groups, swipes, wrapping) are stored in
  `~/Library/Preferences/io.alberti42.SpaceJumper.plist`.

## Troubleshooting

- **Swipes switch with macOS's animation.** SpaceJumper lacks Accessibility
  access, or "Switch instantly on trackpad swipes" is off. Settings →
  Shortcuts shows both.
- **Swipes do nothing.** Check how many fingers macOS uses: Settings →
  Shortcuts shows "Swipe set in macOS" (Trackpad → More Gestures → Swipe
  between full-screen applications). Choosing Dragging style Three Finger Drag
  in Accessibility → Pointer Control → Trackpad Options moves this swipe to
  four fingers.
- **A swipe at the first or last desktop does nothing.** There is no Space
  in that direction. Turn on "Wrap around from the last Space to the first"
  to go to the other end.
- **A shortcut switches with the animation, or twice.** A macOS shortcut on the
  same keys is still on. Settings → Shortcuts lists it under Conflicts, with a
  button to Keyboard Shortcuts; see
  [Turn off the system shortcuts](#turn-off-the-system-shortcuts).
- **Desktop numbers change by themselves.** macOS's "Automatically rearrange
  Spaces based on most recent use" is on (Settings → General shows it). Turn
  it off in Desktop & Dock → Mission Control to keep the order you set.

If none of these applies, please open an
[issue](https://github.com/alberti42/SpaceJumper/issues) with your macOS
version and what you did. A log helps: run

```sh
/usr/bin/log stream --level debug --predicate 'subsystem == "io.alberti42.SpaceJumper"'
```

in Terminal, repeat the problem, and attach the output.

## How it works

### Keyboard shortcuts

The animation is drawn by the Dock. When you switch Spaces, the Dock shows both
Spaces, slides them across the screen, and then tells WindowServer to make the
new Space current. WindowServer makes that change at once.

SpaceJumper sends WindowServer the same three requests the Dock sends,
without the slide: show the new Space, make it current, hide the other Spaces.
It uses SkyLight's bridged window-management operations
(`SLSBridgedShowSpacesOperation`, `SLSBridgedManagedDisplaySetCurrentSpaceOperation`,
`SLSBridgedHideSpacesOperation`). SkyLight is the private framework through
which apps and the Dock talk to WindowServer.

The plain SkyLight functions are not enough. Called from an app other than the
Dock, `SLSManagedDisplaySetCurrentSpace` changes the Space, but
`SLSShowSpaces` and `SLSHideSpaces` are refused, so the windows of both Spaces
stay on screen. The bridged operations are accepted.

With a slide animation set, SpaceJumper draws the slide itself, as the Dock
does: it shows the new Space shifted one screen width to the side, moves both
Spaces across the screen about 120 times a second
(`SLSBridgedSpaceSetTransformOperation`), and then sends the same three
requests and puts both Spaces back in place.

### Trackpad swipes

A swipe between Spaces reaches the Dock as a series of "Dock swipe" events:
began, changed (with the distance moved), ended. SpaceJumper watches them
with an event tap placed before the Dock. It drops the began event, so the
Dock never starts its slide; at the first changed event that moved, it
switches one Space in that direction, as the keyboard shortcuts do. From macOS
27 on, the ended event is passed on with its motion set to zero, because the
Dock needs it to finish the gesture. Swipes inside Mission Control are
intercepted in the same way. Swipes inside App Exposé are left to the Dock,
which does not switch Spaces there; SpaceJumper recognises App Exposé from
the Dock's accessibility elements when a swipe begins.

## Building from source

Requires the Swift 6.2 toolchain or later (Xcode or the Command Line Tools).
No Xcode project is involved.

```sh
make app     # build/SpaceJumper.app, signed ad hoc
make run     # build and open it
make test    # run the tests
```

Open the app from the Finder or with `open build/SpaceJumper.app`. Started
from a shell as `Contents/MacOS/SpaceJumper`, macOS attributes its
Accessibility request to the shell. macOS also ties the Accessibility
permission to the app's signature: an app signed ad hoc gets a new signature
with every build, so the permission has to be granted again after each build.
A build signed with a Developer ID keeps it.

`ARCHS=universal make app` builds for Apple silicon and Intel; the default is
this Mac's architecture. To sign with a Developer ID, set `SIGN_IDENTITY`:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

To use your own signing identity, also change the bundle identifiers
`io.alberti42.SpaceJumper` and `io.alberti42.SpaceJumper.LoginHelper` in
`Resources/Info.plist`, `Resources/LoginHelper-Info.plist`,
`Sources/LoginHelper/main.swift` and `Sources/SpaceJumper/LoginItem.swift`.
To publish your own updates, set `SUFeedURL` (your appcast) and
`SUPublicEDKey` (your EdDSA public key) in `Resources/Info.plist`; otherwise
your build offers the updates published in this repository.

The executable also takes commands, which switch once and exit:

```sh
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --list            # displays and Spaces
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --move right
build/SpaceJumper.app/Contents/MacOS/SpaceJumper --desktop 2
```

## Credits

- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) by
  jurplel skips the animation by sending the Dock a trackpad swipe with a very
  high velocity. SpaceJumper intercepts swipes following its findings on the
  Dock's swipe events: the event fields and the handling of the ended event on
  macOS 27.
- [yabai](https://github.com/asmvik/yabai) by asmvik uses the bridged
  operations to move windows between Spaces
  ([#2788](https://github.com/asmvik/yabai/issues/2788)); SpaceJumper looks up
  SkyLight's private perform function the same way.

The app was created with AI assistance (Claude).

## License

[GNU General Public License v3.0](LICENSE)
