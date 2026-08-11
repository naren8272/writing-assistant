import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Reads the current selection out of whatever app is frontmost.
///
/// Two strategies: the Accessibility API first (clean, never touches the pasteboard), then a
/// synthetic ⌘C as fallback for apps that don't expose `AXSelectedText` — Electron, most
/// browsers' page content, terminal emulators. Both need Accessibility permission.
enum TextCapture {
    private static let copyTimeout: TimeInterval = 0.4
    private static let modifierReleaseTimeout: TimeInterval = 0.5
    private static let pollInterval: useconds_t = 10_000

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that deep-links to System Settings › Privacy & Security › Accessibility.
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Blocking — call off the main thread.
    static func selectedText() -> String? {
        if let text = viaAccessibility(), !text.isEmpty { return text }
        return viaCopyCommand()
    }

    private static func viaAccessibility() -> String? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(),
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        var selection: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement,
                                            kAXSelectedTextAttribute as CFString,
                                            &selection) == .success else { return nil }
        return selection as? String
    }

    private static func viaCopyCommand() -> String? {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let changeCountBefore = pasteboard.changeCount

        waitForModifiersToClear()
        postCommandC()

        var captured: String?
        let deadline = Date().addingTimeInterval(copyTimeout)
        while Date() < deadline {
            if pasteboard.changeCount != changeCountBefore {
                captured = pasteboard.string(forType: .string)
                break
            }
            usleep(pollInterval)
        }

        restore(pasteboard, to: saved)
        return captured
    }

    /// The hotkey's own modifiers are still physically held when it fires. Posting ⌘C while ⌥ is
    /// down lands as ⌥⌘C in the target app, so wait them out first.
    private static func waitForModifiersToClear() {
        let deadline = Date().addingTimeInterval(modifierReleaseTimeout)
        while Date() < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let blocking: CGEventFlags = [.maskAlternate, .maskControl, .maskShift]
            if flags.intersection(blocking).isEmpty { return }
            usleep(pollInterval)
        }
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = CGKeyCode(kVK_ANSI_C)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [[String: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var payload: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { payload[type.rawValue] = data }
            }
            return payload
        }
    }

    private static func restore(_ pasteboard: NSPasteboard, to snapshot: [[String: Data]]) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }

        let items = snapshot.map { payload -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in payload {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
