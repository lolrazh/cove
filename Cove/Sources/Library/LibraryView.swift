import SwiftUI

/// The Library's sections under a segmented control. The sidebar and the
/// popover each wrap it in their own frame.
struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 8) {
            LibrarySectionPicker(selection: $model.section)

            switch model.section {
            case .downloads:
                LibraryDownloads(manager: model.downloads)
            case .archive:
                LibraryArchive(model: model, archive: model.archive, query: $query)
            case .history:
                LibraryHistory(model: model, historyStore: model.historyStore, query: $query)
            }
        }
        .onChange(of: model.section) { query = "" }
    }
}

/// The sections as equal tabs, the selected one raised like the sidebar's
/// active tab. A system segmented control would ask for more width than a
/// narrow sidebar has.
private struct LibrarySectionPicker: View {
    @Binding var selection: LibraryModel.Section

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryModel.Section.allCases) { section in
                Button { selection = section } label: {
                    Text(section.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(section == selection ? .primary : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: ChromeMetrics.iconButtonSize)
                        .background {
                            if section == selection {
                                ConcentricRectangle.chrome(minimum: ChromeRadius.control)
                                    .fill(ChromePalette.raised)
                                    .chromeShadow(.raised)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == selection ? .isSelected : [])
            }
        }
        .padding(2)
        .background(ChromePalette.resting, in: .chrome(minimum: ChromeRadius.tab))
        .animation(ChromeMotion.hover, value: selection)
    }
}

/// The Library in the sidebar, in the tabs' place: Back and a title on the
/// traffic lights' line, then the sections.
struct SidebarLibrary: View {
    let model: LibraryModel
    let headerHeight: CGFloat
    let headerLeadingInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: model.dismiss) {
                    Image(systemName: ChromeSymbols.Navigation.back)
                }
                .buttonStyle(ChromeButtonStyle())
                .help("Back to Tabs")

                Text("Library")
                    .font(.headline)

                Spacer(minLength: 0)
            }
            .padding(.leading, headerLeadingInset)
            .padding(.trailing, ChromeMetrics.sidebarInset)
            .frame(height: headerHeight)

            LibraryView(model: model)
                .padding(.horizontal, ChromeMetrics.sidebarInset)
        }
    }
}

/// The row of tools above a section's list: a search field, or Clear.
struct LibraryToolbar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
        }
        .frame(height: ChromeMetrics.iconButtonSize)
    }
}

struct LibrarySearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ChromeSymbols.Navigation.search)
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onExitCommand { text = "" }
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .chromeFieldStyle(focused: isFocused)
    }
}

/// A section's rows, or a quiet line saying there are none.
struct LibraryList<Content: View>: View {
    let isEmpty: Bool
    let emptyText: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(.bottom, ChromeMetrics.sidebarSectionSpacing)
        }
        .scrollIndicators(.never)
        .overlay {
            if isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// One row in the Library: an icon, a title over a detail line, and an
/// accessory at the trailing edge that knows whether the row is hovered.
struct LibraryRow<Icon: View, Detail: View, Accessory: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let detail: () -> Detail
    @ViewBuilder let accessory: (_ isHovered: Bool) -> Accessory

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            icon()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .lineLimit(1)

                detail()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory(isHovered)
        }
        .padding(.leading, 6)
        .padding(.trailing, ChromeMetrics.tabAccessoryInset)
        .frame(height: 40)
        // Makes the accessory's ConcentricRectangle follow this row's corners.
        .containerShape(RoundedRectangle(cornerRadius: ChromeRadius.tab, style: .continuous))
        .background {
            if isHovered {
                ConcentricRectangle.chrome(minimum: ChromeRadius.tab)
                    .fill(ChromePalette.hover)
            }
        }
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: action)
    }
}

extension ButtonStyle where Self == ChromeButtonStyle {
    /// A button at the end of a Library row.
    static var libraryAccessory: Self {
        ChromeButtonStyle(size: .accessory(side: 24))
    }
}
