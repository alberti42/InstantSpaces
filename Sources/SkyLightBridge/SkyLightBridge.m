#import "SkyLightBridge.h"

#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <objc/message.h>
#import <string.h>

static NSString *const kSkyLightPath = @"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight";
// WMClientWindowManager lives here. Without it the fallback bridge's manager is
// nil and every bridged operation is dropped without an error.
static NSString *const kWindowManagementPath = @"/System/Library/PrivateFrameworks/WindowManagement.framework/Versions/A/WindowManagement";
// Static C++ function in SkyLight; it is in the symbol table but not exported.
static const char *const kPerformSymbol =
    "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation";

typedef int CGSConnectionID;

static CGSConnectionID (*sMainConnectionID)(void);
static CFArrayRef (*sCopyManagedDisplaySpaces)(CGSConnectionID);
static CFStringRef (*sCopyActiveMenuBarDisplayIdentifier)(CGSConnectionID);
static uint64_t (*sGetActiveSpace)(CGSConnectionID);
static bool (*sIsSymbolicHotKeyEnabled)(int);
static int (*sGetSymbolicHotKeyValue)(int, uint16_t *, uint16_t *, uint64_t *);
// Returns a pointer to a static buffer, overwritten by the next call.
static const char *(*sSymbolicHotKeyName)(int);
static bool (*sIsEventMatchingSymbolicHotKey)(CGSConnectionID, CGEventRef, int);
static void (*sPerform)(id);

/// Finds a symbol, including a local one, in the symbol table of a loaded image.
static void *FindSymbol(NSString *imagePath, const char *name)
{
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *imageName = _dyld_get_image_name(i);
        if (!imageName || strcmp(imageName, imagePath.fileSystemRepresentation) != 0) continue;

        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const struct segment_command_64 *linkedit = NULL;
        const struct symtab_command *symtab = NULL;

        const uint8_t *cursor = (const uint8_t *)(header + 1);
        for (uint32_t c = 0; c < header->ncmds; ++c) {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (strcmp(segment->segname, SEG_LINKEDIT) == 0) linkedit = segment;
            } else if (command->cmd == LC_SYMTAB) {
                symtab = (const struct symtab_command *)command;
            }
            cursor += command->cmdsize;
        }
        if (!linkedit || !symtab) return NULL;

        uintptr_t base = linkedit->vmaddr - linkedit->fileoff + (uintptr_t)slide;
        const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
        const char *strings = (const char *)(base + symtab->stroff);
        for (uint32_t s = 0; s < symtab->nsyms; ++s) {
            if (strcmp(strings + symbols[s].n_un.n_strx, name) == 0) {
                return (void *)(symbols[s].n_value + (uintptr_t)slide);
            }
        }
        return NULL;
    }
    return NULL;
}

BOOL SLBLoad(NSString **error)
{
    void *skyLight = dlopen(kSkyLightPath.fileSystemRepresentation, RTLD_NOW);
    if (!skyLight) {
        if (error) *error = @"Cannot load SkyLight.framework.";
        return NO;
    }
    if (!dlopen(kWindowManagementPath.fileSystemRepresentation, RTLD_NOW) || !NSClassFromString(@"WMClientWindowManager")) {
        if (error) *error = @"Cannot load WindowManagement.framework (WMClientWindowManager).";
        return NO;
    }

    sMainConnectionID = dlsym(skyLight, "SLSMainConnectionID");
    sCopyManagedDisplaySpaces = dlsym(skyLight, "SLSCopyManagedDisplaySpaces");
    sCopyActiveMenuBarDisplayIdentifier = dlsym(skyLight, "SLSCopyActiveMenuBarDisplayIdentifier");
    sGetActiveSpace = dlsym(skyLight, "SLSGetActiveSpace");
    sIsSymbolicHotKeyEnabled = dlsym(skyLight, "SLSIsSymbolicHotKeyEnabled");
    sGetSymbolicHotKeyValue = dlsym(skyLight, "SLSGetSymbolicHotKeyValue");
    sSymbolicHotKeyName = dlsym(skyLight, "SLSSymbolicHotKeyName");
    sIsEventMatchingSymbolicHotKey = dlsym(skyLight, "SLSIsEventMatchingSymbolicHotKey");
    sPerform = FindSymbol(kSkyLightPath, kPerformSymbol);

    NSMutableArray *missing = [NSMutableArray array];
    if (!sMainConnectionID) [missing addObject:@"SLSMainConnectionID"];
    if (!sCopyManagedDisplaySpaces) [missing addObject:@"SLSCopyManagedDisplaySpaces"];
    if (!sCopyActiveMenuBarDisplayIdentifier) [missing addObject:@"SLSCopyActiveMenuBarDisplayIdentifier"];
    if (!sGetActiveSpace) [missing addObject:@"SLSGetActiveSpace"];
    if (!sIsSymbolicHotKeyEnabled) [missing addObject:@"SLSIsSymbolicHotKeyEnabled"];
    if (!sGetSymbolicHotKeyValue) [missing addObject:@"SLSGetSymbolicHotKeyValue"];
    if (!sSymbolicHotKeyName) [missing addObject:@"SLSSymbolicHotKeyName"];
    if (!sIsEventMatchingSymbolicHotKey) [missing addObject:@"SLSIsEventMatchingSymbolicHotKey"];
    if (!sPerform) [missing addObject:@"SLSPerformAsynchronousBridgedWindowManagementOperation"];
    for (NSString *name in @[@"SLSBridgedShowSpacesOperation", @"SLSBridgedHideSpacesOperation",
                             @"SLSBridgedManagedDisplaySetCurrentSpaceOperation"]) {
        if (!NSClassFromString(name)) [missing addObject:name];
    }
    if (missing.count > 0) {
        if (error) *error = [NSString stringWithFormat:@"Missing in SkyLight: %@.", [missing componentsJoinedByString:@", "]];
        return NO;
    }
    return YES;
}

NSArray<NSDictionary *> *SLBCopyManagedDisplaySpaces(void)
{
    return CFBridgingRelease(sCopyManagedDisplaySpaces(sMainConnectionID()));
}

NSString *SLBActiveMenuBarDisplay(void)
{
    return CFBridgingRelease(sCopyActiveMenuBarDisplayIdentifier(sMainConnectionID()));
}

uint64_t SLBActiveSpace(void)
{
    return sGetActiveSpace(sMainConnectionID());
}

static BOOL PerformSpacesOperation(NSString *className, NSArray<NSNumber *> *spaces)
{
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    id operation = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], sel_registerName("initWithSpaces:"), spaces);
    if (!operation) return NO;
    sPerform(operation);
    return YES;
}

BOOL SLBShowSpaces(NSArray<NSNumber *> *spaces)
{
    return PerformSpacesOperation(@"SLSBridgedShowSpacesOperation", spaces);
}

BOOL SLBHideSpaces(NSArray<NSNumber *> *spaces)
{
    return PerformSpacesOperation(@"SLSBridgedHideSpacesOperation", spaces);
}

BOOL SLBSetCurrentSpace(NSString *display, uint64_t space)
{
    Class cls = NSClassFromString(@"SLSBridgedManagedDisplaySetCurrentSpaceOperation");
    if (!cls) return NO;
    id operation = ((id (*)(id, SEL, id, uint64_t))objc_msgSend)(
        [cls alloc], sel_registerName("initWithDisplayIdentifier:spaceID:"), display, space);
    if (!operation) return NO;
    sPerform(operation);
    return YES;
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *SLBCopyEnabledSymbolicHotKeys(void)
{
    NSMutableArray *result = [NSMutableArray array];
    for (int hotKey = 0; hotKey < 512; ++hotKey) {
        uint16_t character = 0, keyCode = 0;
        uint64_t flags = 0;
        // 0xFFFF marks a shortcut without a key.
        if (sGetSymbolicHotKeyValue(hotKey, &character, &keyCode, &flags) != 0 || keyCode == 0xFFFF) continue;
        if (!sIsSymbolicHotKeyEnabled(hotKey)) continue;
        [result addObject:@{@"id": @(hotKey), @"keyCode": @(keyCode), @"flags": @(flags)}];
    }
    return result;
}

NSString *SLBSymbolicHotKeyName(int hotKey)
{
    const char *name = sSymbolicHotKeyName(hotKey);
    return name && name[0] ? [NSString stringWithUTF8String:name] : nil;
}

BOOL SLBEventMatchesSymbolicHotKey(uint16_t keyCode, uint64_t flags, int hotKey)
{
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    if (!event) return NO;
    CGEventSetFlags(event, flags);
    BOOL matches = sIsEventMatchingSymbolicHotKey(sMainConnectionID(), event, hotKey);
    CFRelease(event);
    return matches;
}
