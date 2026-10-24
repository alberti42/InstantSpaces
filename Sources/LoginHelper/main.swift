import AppKit

// Login helper registered with SMAppService.loginItem(identifier:).
// It lives at InstantSpaces.app/Contents/Library/LoginItems/InstantSpacesLoginHelper.app,
// launches the main app if it is not running, and quits.

let mainBundleIdentifier = "io.alberti42.InstantSpaces"

let mainAppURL = Bundle.main.bundleURL   // .../LoginItems/InstantSpacesLoginHelper.app
    .deletingLastPathComponent()         // .../Contents/Library/LoginItems
    .deletingLastPathComponent()         // .../Contents/Library
    .deletingLastPathComponent()         // .../Contents
    .deletingLastPathComponent()         // .../InstantSpaces.app

if !NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleIdentifier).isEmpty {
    exit(0)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false
NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
    if let error {
        NSLog("InstantSpaces login helper: could not open \(mainAppURL.path): \(error.localizedDescription)")
        exit(1)
    }
    exit(0)
}
dispatchMain()
