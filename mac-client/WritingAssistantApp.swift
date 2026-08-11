import SwiftUI

/// The menu-bar icon and popover are owned by `StatusItemController` rather than `MenuBarExtra`,
/// because `MenuBarExtra` exposes no way to open itself programmatically from the global hotkey.
@main
struct WritingAssistantApp: App {
    @NSApplicationDelegateAdaptor(StatusItemController.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
