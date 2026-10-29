# Security Policy

## Supported versions

Only the latest release receives fixes. SpaceJumper updates itself through Sparkle, so a fix reaches users with the next release.

## Reporting a vulnerability

Report a vulnerability privately through GitHub: open the [Security tab](https://github.com/alberti42/SpaceJumper/security) of this repository and choose **Report a vulnerability**. Do not open a public issue for a vulnerability.

Include the SpaceJumper version (select SpaceJumper.app in the Finder and choose File → Get Info), the macOS version, and the steps to reproduce the problem.

## What SpaceJumper does that matters for security

- It uses private macOS interfaces: SkyLight's bridged window-management operations, to show, hide and move Spaces and make one current. It loads no code into other processes.
- With "Switch instantly on trackpad swipes" on, it needs Accessibility access. It uses that access for an event tap that sees only the trackpad's gesture and Dock swipe events, and drops or changes them before the Dock does. It does not read the keyboard. When a swipe begins, it reads the identifiers of the Dock's top-level accessibility elements, to tell whether App Exposé is open.
- The keyboard shortcuts are registered with `RegisterEventHotKey`, which needs no permission.
- It reads the trackpad and Dock preferences it reports in Settings: `com.apple.AppleMultitouchTrackpad` (`TrackpadThreeFingerHorizSwipeGesture`, `TrackpadFourFingerHorizSwipeGesture`) and `com.apple.dock` (`mru-spaces`, `autohide`, `autohide-delay`, `digduration-duration`, `autohide-time-modifier`).
- It writes macOS preferences only when you change them in its Settings: `AppleSpacesSwitchOnActivate` in the global domain, and in `com.apple.dock` `mru-spaces` and the keys of Settings → macOS → Dock. It turns "Automatically hide and show the Dock" on or off through `CoreDockSetAutoHideEnabled`, as System Settings does, and after a change to `mru-spaces` or the other Dock keys it restarts the Dock (`SIGTERM`, as `killall Dock` does).
- It connects to the network only for updates: it downloads `Releases/appcast.xml` from this repository and, when you install an update, `SpaceJumper.zip` from GitHub Releases. Sparkle installs an update only if the ZIP's EdDSA signature matches the public key in the app.
- Each release ZIP is built by GitHub Actions from the tagged source, signed with a Developer ID, notarized by Apple, and carries a build provenance attestation. To check where a downloaded ZIP was built:

  ```sh
  gh attestation verify SpaceJumper.zip --repo alberti42/SpaceJumper
  ```

  The attestation names the workflow (`.github/workflows/draft-release.yml`), the tag and the commit the ZIP was built from.
