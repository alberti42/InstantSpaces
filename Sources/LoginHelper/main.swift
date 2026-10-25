import AppKit

// Login helper registered with SMAppService.loginItem(identifier:).
// It lives at SpaceJumper.app/Contents/Library/LoginItems/SpaceJumperLoginHelper.app,
// launches the main app if it is not running, and quits.

let mainBundleIdentifier = "io.alberti42.SpaceJumper"

let mainAppURL = Bundle.main.bundleURL   // .../LoginItems/SpaceJumperLoginHelper.app
    .deletingLastPathComponent()         // .../Contents/Library/LoginItems
    .deletingLastPathComponent()         // .../Contents/Library
    .deletingLastPathComponent()         // .../Contents
    .deletingLastPathComponent()         // .../SpaceJumper.app

if !NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleIdentifier).isEmpty {
    exit(0)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false
NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
    if let error {
        NSLog("SpaceJumper login helper: could not open \(mainAppURL.path): \(error.localizedDescription)")
        exit(1)
    }
    exit(0)
}
dispatchMain()
