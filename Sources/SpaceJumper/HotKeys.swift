import Carbon.HIToolbox

/// Global hotkeys through Carbon's `RegisterEventHotKey`, which needs no
/// Accessibility permission.
@MainActor
final class HotKeyCenter {
    struct Failure {
        let name: String
        let status: OSStatus
    }

    private static let signature: OSType = 0x496E_5370 // "InSp"

    private var references: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { center.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Registers a hotkey. Returns the failure if the system refuses it. A
    /// combination another app holds is not refused (macOS 27.0.1): both apps
    /// register it, and only one of them receives the key press.
    func register(name: String, keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Failure? {
        let id = nextID
        nextID += 1
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return Failure(name: name, status: status) }
        references.append(reference)
        actions[id] = action
        return nil
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }
}
