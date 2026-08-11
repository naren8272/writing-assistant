import AppKit
import Carbon.HIToolbox

/// Carbon `RegisterEventHotKey` wrapper. Chosen over `NSEvent.addGlobalMonitorForEvents`
/// because it works without Accessibility permission and consumes the keystroke so the
/// frontmost app never sees it.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPress: (() -> Void)?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        unregister()
        self.onPress = onPress

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        // Non-capturing closure so it bridges to a C function pointer; state lives on the singleton.
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { HotKeyCenter.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)

        guard status == noErr else {
            NSLog("hotkey_handler_install_failed status=\(status)")
            return
        }

        let id = EventHotKeyID(signature: OSType(0x57_41_53_53), id: 1) // 'WASS'
        let registered = RegisterEventHotKey(keyCode, modifiers, id,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        if registered != noErr {
            NSLog("hotkey_register_failed status=\(registered) — likely taken by another app")
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        onPress = nil
    }
}
