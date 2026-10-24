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

/// Bridged window-management operations. They are asynchronous; the return
/// value only says whether the operation could be built and handed over.
BOOL SLBShowSpaces(NSArray<NSNumber *> *spaces);
BOOL SLBHideSpaces(NSArray<NSNumber *> *spaces);
BOOL SLBSetCurrentSpace(NSString *display, uint64_t space);

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
