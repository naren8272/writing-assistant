import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "text.badge.checkmark",
                                     accessibilityDescription: "Writing Assistant")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(state)
        )

        HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_R),
                                     modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.captureSelectionAndRewrite()
        }

        if !TextCapture.isTrusted { TextCapture.requestPermission() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyCenter.shared.unregister()
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func captureSelectionAndRewrite() {
        guard TextCapture.isTrusted else {
            TextCapture.requestPermission()
            state.error = "Grant Accessibility permission, then try the shortcut again."
            showPopover()
            return
        }

        // Capture before activating — focusing our own app would destroy the selection we want.
        Task.detached {
            let selection = TextCapture.selectedText()?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let selection, !selection.isEmpty else {
                    self.state.error = "No selected text found in the frontmost app."
                    self.showPopover()
                    return
                }
                self.state.input = selection
                self.showPopover()
                self.state.rewrite()
            }
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
