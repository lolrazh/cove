import SwiftUI

struct BrowserCommandContext {
    let currentTabLayout: TabLayout
    let showHorizontalTabs: () -> Void
    let showSidebarTabs: () -> Void
}

private struct BrowserCommandContextKey: FocusedValueKey {
    typealias Value = BrowserCommandContext
}

extension FocusedValues {
    var browserCommandContext: BrowserCommandContext? {
        get { self[BrowserCommandContextKey.self] }
        set { self[BrowserCommandContextKey.self] = newValue }
    }
}

struct BrowserViewCommands: Commands {
    @FocusedValue(\.browserCommandContext) private var browserCommandContext

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Use Top Tabs") {
                browserCommandContext?.showHorizontalTabs()
            }
            .disabled(
                browserCommandContext == nil
                || browserCommandContext?.currentTabLayout == .horizontal
            )

            Button("Use Sidebar Tabs") {
                browserCommandContext?.showSidebarTabs()
            }
            .disabled(
                browserCommandContext == nil
                || browserCommandContext?.currentTabLayout == .sidebar
            )
        }
    }
}
