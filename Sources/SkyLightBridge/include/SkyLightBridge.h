#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Loads SkyLight and WindowManagement and resolves the private symbols the
/// other functions need. Call once before any of them. Returns NO and sets
/// `error` to a description of the missing piece if one cannot be found.
BOOL SLBLoad(NSString *_Nullable *_Nullable error);

/// `SLSCopyManagedDisplaySpaces` for the main connection: one dictionary per
/// display, with "Display Identifier", "Current Space" and "Spaces".
NSArray<NSDictionary *> *_Nullable SLBCopyManagedDisplaySpaces(void);

/// The identifier of the display that shows the active menu bar.
NSString *_Nullable SLBActiveMenuBarDisplay(void);

/// The current Space of the active display, as WindowServer reports it.
uint64_t SLBActiveSpace(void);

/// The Spaces of a window (`SLSCopySpacesForWindows`), on any display. A
/// window keeps its Space while minimized, while its app is hidden, and while
/// its app keeps it ordered out; some ordered-out windows have none.
NSArray<NSNumber *> *SLBCopySpacesForWindow(uint32_t window);

/// The attributes of each window, by window ID, from SkyLight's window
/// iterator (`SLSWindowIteratorGetAttributes`). Bit 0x2 is set for a window
/// that is ordered in, on the current Space or another, and clear for a
/// minimized window, a window of a hidden app and an ordered-out window
/// (inferred from these cases on macOS 27.0.1).
NSDictionary<NSNumber *, NSNumber *> *SLBCopyWindowAttributes(NSArray<NSNumber *> *windows);

/// Bridged window-management operations. They are asynchronous; the return
/// value only says whether the operation could be built and handed over.
BOOL SLBShowSpaces(NSArray<NSNumber *> *spaces);
BOOL SLBHideSpaces(NSArray<NSNumber *> *spaces);
BOOL SLBSetCurrentSpace(NSString *display, uint64_t space);

/// Draws `space` shifted `x` points to the right of its place (negative: to
/// the left), through `SLSBridgedSpaceSetTransformOperation`. WindowServer
/// reads the transform's translation the other way round, so this passes −x.
/// 0 puts the Space back. Asynchronous, like the operations above.
BOOL SLBSetSpaceOffset(uint64_t space, double x);

/// Freezes the screen for a fade transition (`SLSNewTransition`, type 1):
/// changes made afterwards stay invisible until `SLBDissolveScreen`. Returns
/// the transition's handle, or 0 if WindowServer refused it.
int SLBFreezeScreenForFade(void);

/// Dissolves the frozen screen image into the current screen over `seconds`
/// (`SLSInvokeTransition`). WindowServer fades the whole picture, so the
/// windows keep their order throughout.
BOOL SLBDissolveScreen(int transition, double seconds);

/// Releases a transition after its dissolve (`SLSReleaseTransition`).
void SLBReleaseTransition(int transition);

/// The width in points of the display with this identifier (a UUID), or of
/// the main display when no display has it, as for "Main" when displays
/// share Spaces.
double SLBDisplayWidth(NSString *display);

/// The enabled system shortcuts ("symbolic hotkeys"): one dictionary per
/// shortcut with "id", "keyCode" and "flags" (CGEventFlags). IDs 0–511 are read.
NSArray<NSDictionary<NSString *, NSNumber *> *> *SLBCopyEnabledSymbolicHotKeys(void);

/// The internal name of a system shortcut, e.g. "WorkspacesLeft" for 79 or
/// "WindowTileLeftHalf" for 240 (`SLSSymbolicHotKeyName`).
NSString *_Nullable SLBSymbolicHotKeyName(int hotKey);

/// Whether a key-down event with this key code and these CGEventFlags triggers
/// the system shortcut, as WindowServer decides it
/// (`SLSIsEventMatchingSymbolicHotKey`). A switched-off shortcut never matches.
BOOL SLBEventMatchesSymbolicHotKey(uint16_t keyCode, uint64_t flags, int hotKey);

/// Tells WindowServer whether to switch to a Space with a window of an app
/// that is activated (`SLSSessionSetCurrentSessionWorkspacePreferences` with
/// `kCGSWorkspaceSwitchOnAppActivationKey`). The Dock passes the preference
/// `AppleSpacesSwitchOnActivate` on only when it starts; System Settings'
/// Desktop & Dock pane makes this call after changing it (macOS 27.0.1).
BOOL SLBSetSwitchesOnAppActivation(BOOL on);

/// Shows the hidden menu bar on a display (`SLSSetMenuBarVisibilityOverrideOnDisplay`,
/// 1) or gives it back to macOS (0). Both slide for 0.150 s, as macOS's own
/// reveal (macOS 27.0.1).
BOOL SLBSetMenuBarOverride(uint32_t display, BOOL on);

/// Whether the override is on (`SLSGetMenuBarVisibilityOverrideOnDisplay`).
/// WindowServer turns it off by itself at times, around Space changes.
BOOL SLBMenuBarOverride(uint32_t display);

/// How far the menu bar of the current Space is shown, 0 hidden to 1 shown
/// (`SLSGetSpaceMenuBarReveal`).
double SLBMenuBarReveal(void);

/// Calls `handler` on the main queue with the Space of every menu-bar reveal
/// WindowServer announces (notification 0x524). Needs a running NSApplication.
void SLBObserveMenuBarReveals(void (^handler)(uint64_t space));

/// Whether the menu bar hides on desktops (`CGSSetMenuBarAutohideEnabled`), as
/// System Settings → Menu Bar sets it.
BOOL SLBSetMenuBarAutohide(BOOL on);

NS_ASSUME_NONNULL_END
