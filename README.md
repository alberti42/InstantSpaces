# InstantSpaces

A menu-bar app for macOS that switches between Spaces without the slide
animation.

macOS has no setting to turn the animation off. The animation is drawn by the
Dock; WindowServer itself changes the current Space at once. InstantSpaces asks
WindowServer for the switch directly, through private SkyLight calls, so the
Dock never animates.

## Shortcuts

| Shortcut | Action |
|---|---|
| ⌃← / ⌃→ | Move one Space left / right |
| ⌃⌘1 … ⌃⌘9 | Go to desktop 1 … 9 |

macOS binds ⌃← and ⌃→ to its own animated switch by default. Turn them off in
System Settings → Keyboard → Keyboard Shortcuts → Mission Control ("Move left a
space", "Move right a space"); otherwise both switches run.

## Build

Requires macOS 26 or later and the Swift toolchain (Command Line Tools or Xcode).

```sh
make app    # build/InstantSpaces.app
make run
```
