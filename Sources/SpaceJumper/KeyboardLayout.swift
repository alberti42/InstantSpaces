import Carbon.HIToolbox

/// Which key types a letter. `RegisterEventHotKey` takes key codes, which name
/// key positions: on a German keyboard the key that types Z is the ANSI Y key.
enum KeyboardLayout {
    /// The key code that types `letter` without modifiers on the current
    /// keyboard layout, or on the last Latin one when the current layout is not
    /// (Cyrillic, for example); nil when no key types it.
    static func keyCode(for letter: Character) -> Int? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let wanted = String(letter).lowercased()
        for keyCode in 0..<128 {
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count,
                                        &length, &characters)
            if status == noErr, String(utf16CodeUnits: characters, count: length) == wanted { return keyCode }
        }
        return nil
    }
}
