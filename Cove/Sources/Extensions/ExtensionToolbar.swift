import SwiftUI
import WebKit

/// Extensions' buttons, at the end of the sidebar's header row and of the
/// navigation bar with tabs on top. As many as fit show; the rest wait in a
/// menu at the end, and in a sidebar too narrow even for the menu, they're
/// left to the site controls' shelf and the Command Bar. Each shows its
/// action for the active tab: icon, badge and title, and opens its popup
/// from where it sits.
struct ExtensionToolbar: View {
    @ObservedObject var host: ExtensionHost
    @ObservedObject var window: ExtensionWindow
    let tabManager: TabManager

    init(tabManager: TabManager) {
        self.host = tabManager.extensionHost
        self.window = tabManager.extensionWindow
        self.tabManager = tabManager
    }

    var body: some View {
        let buttons = tabManager.extensionContexts.map { ExtensionButton($0, in: window.activeTab) }
        if !buttons.isEmpty {
            ViewThatFits(in: .horizontal) {
                ForEach(Self.layouts(for: buttons.count), id: \.self) { shown in
                    row(buttons, showing: shown)
                }
                // Never at the cost of the navigation buttons.
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }

    /// How many buttons to try showing, most first. The menu takes a
    /// button's room, so it never holds just one: that one shows instead.
    private static func layouts(for count: Int) -> [Int] {
        (0...count).reversed().filter { $0 != count - 1 }
    }

    private func row(_ buttons: [ExtensionButton], showing count: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(buttons.prefix(count)) { button in
                ExtensionActionButton(button: button, tabManager: tabManager)
            }
            if count < buttons.count {
                overflowMenu(Array(buttons.dropFirst(count)))
            }
        }
    }

    private func overflowMenu(_ buttons: [ExtensionButton]) -> some View {
        Menu {
            ForEach(buttons) { button in
                Button {
                    tabManager.performExtensionAction(button.context)
                } label: {
                    // Menus show only plain images.
                    if let icon = button.icon {
                        Label { Text(button.label) } icon: { Image(nsImage: icon) }
                    } else {
                        Text(button.label)
                    }
                }
                .disabled(!button.isEnabled)
            }
        } label: {
            Image(systemName: ChromeSymbols.Extensions.extensions)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ChromeButtonStyle())
        .fixedSize()
        .help("More Extensions")
        .extensionPopoverAnchor(ExtensionWindow.menuAnchorID, in: tabManager)
    }
}

/// Every extension's button, under the site controls: always within reach,
/// however narrow the sidebar. A popup opens from the site controls' glyph.
struct ExtensionShelf: View {
    @ObservedObject var host: ExtensionHost
    @ObservedObject var window: ExtensionWindow
    let tabManager: TabManager

    init(tabManager: TabManager) {
        self.host = tabManager.extensionHost
        self.window = tabManager.extensionWindow
        self.tabManager = tabManager
    }

    var body: some View {
        let buttons = tabManager.extensionContexts.map { ExtensionButton($0, in: window.activeTab) }
        if !buttons.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Extensions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: ChromeMetrics.iconButtonSize), spacing: 4)], alignment: .leading, spacing: 4) {
                    ForEach(buttons) { button in
                        Button {
                            perform(button.context)
                        } label: {
                            ExtensionButtonLabel(button: button)
                        }
                        .buttonStyle(ChromeButtonStyle())
                        .disabled(!button.isEnabled)
                        .help(button.label)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    /// The site controls close first; the popup takes their place.
    private func perform(_ context: WKWebExtensionContext) {
        tabManager.isShowingSiteControls = false
        DispatchQueue.main.async { [tabManager] in
            tabManager.performExtensionAction(context)
        }
    }
}

/// What an extension's button shows, read from its action when the toolbar
/// draws. The action object stays the same as it changes, so the button is
/// handed these values instead, and redraws when they differ.
private struct ExtensionButton: Identifiable {
    let context: WKWebExtensionContext
    let label: String
    let icon: NSImage?
    let badge: String
    let isEnabled: Bool

    var id: String { context.uniqueIdentifier }

    @MainActor
    init(_ context: WKWebExtensionContext, in tab: ExtensionTab?) {
        let action = context.action(for: tab)
        self.context = context
        label = action?.label ?? context.webExtension.displayName ?? ""
        icon = action?.icon(for: CGSize(width: 16, height: 16))
        badge = action?.badgeText ?? ""
        isEnabled = action?.isEnabled ?? true
    }
}

private struct ExtensionActionButton: View {
    let button: ExtensionButton
    let tabManager: TabManager

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            tabManager.performExtensionAction(button.context)
        } label: {
            ExtensionButtonLabel(button: button)
        }
        .buttonStyle(ChromeButtonStyle())
        .disabled(!button.isEnabled)
        .help(button.label)
        .extensionPopoverAnchor(button.id, in: tabManager)
        .contextMenu {
            if button.context.optionsPageURL != nil {
                Button("Options") { tabManager.openOptions(of: button.context) }
            }
            Button("Manage Extensions\u{2026}") {
                SettingsPane.show(.extensions, with: openSettings)
            }
        }
    }
}

/// An extension's icon, with its badge.
private struct ExtensionButtonLabel: View {
    let button: ExtensionButton

    var body: some View {
        ExtensionIcon(image: button.icon, size: 16)
            .frame(width: ChromeMetrics.iconButtonSize, height: ChromeMetrics.iconButtonSize)
            .overlay(alignment: .bottomTrailing) { badge }
    }

    /// Short text an extension puts on its button, like a count.
    @ViewBuilder
    private var badge: some View {
        if !button.badge.isEmpty {
            Text(button.badge)
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .frame(minWidth: 13, minHeight: 13)
                .background(Color.accentColor, in: .capsule)
                .padding(1)
        }
    }
}

extension View {
    /// Lets extensions' popups in the tab manager's window point at this view.
    func extensionPopoverAnchor(_ id: String, in tabManager: TabManager) -> some View {
        background(PopoverAnchor { tabManager.extensionWindow.addAnchor($0, for: id) })
    }
}

/// Hands the view it sits behind to a window's popups to point at.
private struct PopoverAnchor: NSViewRepresentable {
    let register: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        register(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
