import SwiftUI

/// The Command Bar, floating over the window: a large field and the ranked
/// rows beneath it. Centered across the whole window, with a stable input
/// position as results change. A click outside dismisses it.
struct CommandBarOverlay: View {
    @ObservedObject var model: CommandBarModel
    let onOpenLittleCove: () -> Void

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private enum Metrics {
        static let width: CGFloat = 600
        static let inset: CGFloat = 20
    }

    var body: some View {
        GeometryReader { geometry in
            let listHeight = min(CommandBarMetrics.maxListHeight, max(0,
                geometry.size.height - Metrics.inset * 2 - CommandBarMetrics.fieldHeight - CommandBarMetrics.footerHeight))
            let panelHeight = CommandBarMetrics.fieldHeight + listHeight + CommandBarMetrics.footerHeight
            ZStack {
                if model.isPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: model.dismiss)

                    CommandBarPanel(
                        model: model,
                        maxListHeight: listHeight,
                        onOpen: open
                    )
                    .frame(width: min(Metrics.width, max(0, geometry.size.width - Metrics.inset * 2)))
                    // Center the full results area, but keep the field still
                    // when a query produces fewer rows.
                    .frame(height: panelHeight, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Address entry is a frequent keyboard action. Present and dismiss
        // immediately, including when the surrounding shell is animating.
        .transaction { $0.animation = nil }
    }

    /// Scenes can only be opened from a view's environment, so those commands
    /// run here; the model does the rest.
    private func open(_ result: CommandBarResult, inNewTab: Bool) {
        switch result.kind {
        case .command(.newWindow): openWindow(id: BrowserView.windowID)
        case .command(.newPrivateWindow): openWindow(id: BrowserView.privateWindowID)
        case .command(.newLittleCove): onOpenLittleCove()
        case .command(.showHistory): openWindow(id: HistoryWindow.windowID)
        case .command(.extensions): SettingsPane.show(.extensions, with: openSettings)
        case .command(.settings): openSettings()
        default: break
        }
        model.open(result, inNewTab: inNewTab)
    }
}

private enum CommandBarMetrics {
    static let fieldHeight: CGFloat = 56
    static let footerHeight: CGFloat = 28
    static let maxListHeight: CGFloat = 360
    static let actionRowHeight: CGFloat = 40
    static let pageRowHeight: CGFloat = 48
}

private struct CommandBarPanel: View {
    @ObservedObject var model: CommandBarModel
    let maxListHeight: CGFloat
    let onOpen: (CommandBarResult, Bool) -> Void

    private enum Metrics {
        static let headerHeight: CGFloat = 24
        static let listInset: CGFloat = 10
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            if !model.sections.isEmpty {
                results
                footer
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .chromeShadow(.panel)
        .onExitCommand(perform: model.dismiss)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search and commands")
    }

    private var field: some View {
        HStack(spacing: 12) {
            // Split View mode says where the page will open.
            Image(systemName: model.mode == .splitView ? ChromeSymbols.Tabs.splitView : ChromeSymbols.Navigation.search)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            CommandBarField(
                text: $model.query,
                completion: model.completion,
                placeholder: model.mode == .splitView ? "Open in Split View" : "Search or enter URL",
                onKey: handle
            )
            .frame(maxWidth: .infinity)

            Button(action: model.dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle())
            .accessibilityLabel("Close search")
            .help("Close search (Esc)")
        }
        .padding(.leading, 22)
        .padding(.trailing, 14)
        .frame(height: CommandBarMetrics.fieldHeight)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.sections) { section in
                        if let title = section.title {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 12)
                                .frame(height: Metrics.headerHeight, alignment: .bottomLeading)
                                .padding(.bottom, 4)
                        }
                        ForEach(section.results) { result in
                            Button { onOpen(result, false) } label: {
                                CommandBarRow(
                                    result: result,
                                    query: model.query,
                                    detail: detail(for: result),
                                    icon: model.icon(for: result),
                                    isSelected: result == model.selection
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(result.title)
                            .accessibilityValue(detail(for: result) ?? "")
                            .accessibilityAddTraits(result == model.selection ? .isSelected : [])
                            .help([result.title, detail(for: result)].compactMap { $0 }.joined(separator: "\n"))
                            .id(result)
                        }
                    }
                }
                .padding(Metrics.listInset)
            }
            .frame(height: listHeight)
            .onChange(of: model.selection) { _, selection in
                if let selection { proxy.scrollTo(selection) }
            }
        }
    }

    /// Rows are fixed height, so the list is sized exactly to them rather than
    /// letting the scroll view claim profile it doesn't fill.
    private var listHeight: CGFloat {
        let rows = model.results.reduce(CGFloat.zero) {
            $0 + (detail(for: $1) == nil ? CommandBarMetrics.actionRowHeight : CommandBarMetrics.pageRowHeight)
        }
        let headers = CGFloat(model.sections.filter { $0.title != nil }.count) * (Metrics.headerHeight + 4)
        return min(rows + headers + Metrics.listInset * 2, maxListHeight)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text("↑↓ Select")
            Text("↵ Open")
            Spacer()
            Text("Esc Close")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .frame(height: CommandBarMetrics.footerHeight)
        .background(.primary.opacity(0.035))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Use arrow keys or Tab to select. Return to open. Escape to close.")
    }

    private func detail(for result: CommandBarResult) -> String? {
        switch result.kind {
        case .tab, .archived, .history: result.displayURL
        case .search: "\(model.searchEngine.displayName) Search"
        case .url, .suggestion, .command, .profile, .extensionAction, .document: nil
        }
    }

    private func handle(_ key: CommandBarField.Key) {
        switch key {
        case .moveUp: model.moveSelection(by: -1)
        case .moveDown: model.moveSelection(by: 1)
        case .submit(let newTab):
            if let selection = model.selection { onOpen(selection, newTab) }
        case .cancel: model.dismiss()
        }
    }
}

private struct CommandBarRow: View {
    let result: CommandBarResult
    let query: String
    let detail: String?
    let icon: NSImage?
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "return")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: detail == nil ? CommandBarMetrics.actionRowHeight : CommandBarMetrics.pageRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var title: AttributedString {
        var text = AttributedString(result.title)
        text.foregroundColor = .primary
        if case .suggestion = result.kind,
           let match = SuggestionMatch.range(in: result.title, query: query),
           let range = Range(match, in: text) {
            text.foregroundColor = .secondary
            text[range].foregroundColor = .primary
        }
        return text
    }

    @ViewBuilder
    private var iconView: some View {
        switch result.kind {
        case .tab, .archived, .history, .url:
            FaviconView(image: icon, size: 22)
        case .search, .suggestion:
            symbol(ChromeSymbols.Navigation.search)
        case .command(let command):
            symbol(command.symbol)
        case .document(_, let kind):
            symbol(kind.symbol)
        case .profile:
            ProfileIconView()
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
        case .extensionAction:
            ExtensionIcon(image: icon, size: 16)
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(ChromePalette.hover) }
        if isHovered { return AnyShapeStyle(ChromePalette.resting) }
        return AnyShapeStyle(.clear)
    }
}
