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

/// The state of each window, by window ID, from SkyLight's window iterator:
/// "attributes" (`SLSWindowIteratorGetAttributes`) and "tags"
/// (`SLSWindowIteratorGetTags`). Inferred on macOS 27.0.1 from the cases
/// tried: attribute bit 0x2 is set for a window that is ordered in, on the
/// current Space or another, and clear for a minimized window, a window of a
/// hidden app and an ordered-out window. Tag bit 0x8000000000 is set while
/// the window's app is hidden, unless the window was minimized; tag bit
/// 0x1000000000000000 is set while the window is minimized.
NSDictionary<NSNumber *, NSDictionary<NSString *, NSNumber *> *> *SLBCopyWindowStates(NSArray<NSNumber *> *windows);

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

NS_ASSUME_NONNULL_END
