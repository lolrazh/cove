import SwiftUI

struct BrowserCommandContext {
    let showsTabsInSidebar: Bool
    let setShowsTabsInSidebar: (Bool) -> Void
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

            Toggle(
                "Show Tabs in Sidebar",
                isOn: Binding(
                    get: { browserCommandContext?.showsTabsInSidebar ?? false },
                    set: { browserCommandContext?.setShowsTabsInSidebar($0) }
                )
            )
            .disabled(browserCommandContext == nil)
        }
    }
}
