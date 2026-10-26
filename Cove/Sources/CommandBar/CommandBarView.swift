import SwiftUI

/// The Command Bar, floating over the window: a large field and the ranked
/// rows beneath it. Sits in an overlay over the whole shell so it's above the
/// page card and the sidebar alike. A click anywhere else dismisses it.
struct CommandBarOverlay: View {
    @ObservedObject var model: CommandBarModel

    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let width: CGFloat = 620
        /// The panel's top sits this far down the window, like a prompt that
        /// belongs to the page rather than the titlebar.
        static let topFraction: CGFloat = 0.18
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if model.isPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: model.dismiss)

                    CommandBarPanel(model: model, onOpen: open)
                        .frame(width: Metrics.width)
                        .padding(.top, geometry.size.height * Metrics.topFraction)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? ChromeMotion.hover : ChromeMotion.commandBar, value: model.isPresented)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
    }

    private func open(_ result: CommandBarResult, inNewTab: Bool) {
        if case .command(.showHistory) = result.kind {
            openWindow(id: HistoryWindow.windowID)
        }
        model.open(result, inNewTab: inNewTab)
    }
}

private struct CommandBarPanel: View {
    @ObservedObject var model: CommandBarModel
    let onOpen: (CommandBarResult, Bool) -> Void

    private enum Metrics {
        static let fieldHeight: CGFloat = 56
        static let rowHeight: CGFloat = 36
        static let headerHeight: CGFloat = 28
        static let listInset: CGFloat = 8
        static let maxListHeight: CGFloat = 480
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            if !model.sections.isEmpty {
                Divider()
                results
            }
        }
        .background(.thickMaterial, in: .chrome(minimum: ChromeRadius.tile))
        .compositingGroup()
        .shadow(color: .black.opacity(0.24), radius: 28, y: 10)
    }

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: ChromeSymbols.Navigation.search)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            CommandBarField(
                text: $model.query,
                completion: model.completion,
                placeholder: "Search or enter URL",
                onKey: handle
            )
        }
        .padding(.horizontal, 18)
        .frame(height: Metrics.fieldHeight)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.sections) { section in
                        if let title = section.title {
                            Text(title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 10)
                                .frame(height: Metrics.headerHeight, alignment: .bottomLeading)
                                .padding(.bottom, 4)
                        }
                        ForEach(section.results) { result in
                            CommandBarRow(
                                result: result,
                                detail: detail(for: result),
                                icon: model.icon(for: result),
                                isSelected: result == model.selection
                            )
                            .frame(height: Metrics.rowHeight)
                            .onTapGesture { onOpen(result, false) }
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
    /// letting the scroll view claim space it doesn't fill.
    private var listHeight: CGFloat {
        let rows = CGFloat(model.results.count) * Metrics.rowHeight
        let headers = CGFloat(model.sections.filter { $0.title != nil }.count) * (Metrics.headerHeight + 4)
        return min(rows + headers + Metrics.listInset * 2, Metrics.maxListHeight)
    }

    private func detail(for result: CommandBarResult) -> String? {
        switch result.kind {
        case .tab, .history: result.displayURL
        case .search: "\(model.searchEngine.displayName) Search"
        case .url, .suggestion, .command: nil
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
    let detail: String?
    let icon: NSImage?
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 20, height: 20)

            Text(result.title)
                .lineLimit(1)
                .layoutPriority(1)

            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .font(.body)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: .chrome(minimum: ChromeRadius.control))
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        switch result.kind {
        case .tab, .history, .url:
            FaviconView(image: icon, size: 16)
        case .search, .suggestion:
            symbol(ChromeSymbols.Navigation.search)
        case .command(let command):
            symbol(command.symbol)
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
