import SwiftUI

/// Saved pages use the existing profile pin store, including its folders.
struct BookmarkButton: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var page: TabSession
    @Binding var isPresented: Bool

    private var isPinned: Bool { tabManager.section(of: page.id) == .pinned }

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: isPinned ? "bookmark.fill" : "bookmark")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle())
        .disabled(page.siteURL == nil || tabManager.isPrivate)
        .help("Save Page")
        .accessibilityLabel("Save Page")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isPinned ? "Saved in this profile" : "Save in this profile")
                    .font(.headline).padding(8)
                Button {
                    tabManager.togglePinned(page.id)
                    isPresented = false
                } label: {
                    Label(isPinned ? "Unpin Tab" : "Pin Tab", systemImage: isPinned ? "pin.slash" : "pin")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                .buttonStyle(ChromeButtonStyle(size: .row))
                let folders = tabManager.pinned.folders
                if !folders.isEmpty {
                    Divider().padding(.vertical, 4)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(folders) { folder in
                                Button {
                                    tabManager.moveTabToPins(page.id, at: .into(folder.id))
                                    isPresented = false
                                } label: {
                                    Label(folder.name, systemImage: "folder")
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                                }
                                .buttonStyle(ChromeButtonStyle(size: .row))
                            }
                        }
                    }.frame(maxHeight: 220)
                }
                Button {
                    if !isPinned { tabManager.pinTab(page.id) }
                    tabManager.newFolder(around: page.id)
                    isPresented = false
                } label: {
                    Label("New Folder…", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.buttonStyle(ChromeButtonStyle(size: .row))
            }.padding(8).frame(width: 240)
        }
    }
}

struct SplitControl: View {
    @ObservedObject var tabManager: TabManager
    let page: TabSession
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            tabManager.selectTab(page.id)
            if tabManager.activeSplit == nil { tabManager.addSplitView() }
            else { isPresented.toggle() }
        } label: {
            Image(systemName: "rectangle.split.2x1").foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle())
        .disabled(tabManager.section(of: page.id) != .today)
        .help("Split View")
        .accessibilityLabel("Split View")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Button("Add Pane…") { isPresented = false; tabManager.addSplitView() }
                    .disabled(!tabManager.canAddSplitPane)
                if let split = tabManager.activeSplit {
                    Button("Rotate Split") { tabManager.rotateSplit(split.id) }
                    Button("Equal Sizes") {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) {
                            tabManager.equalizeSplit(split.id)
                        }
                    }
                    Divider()
                    Button("Separate Tabs") { isPresented = false; tabManager.separateSplit(split.id) }
                }
            }.buttonStyle(ChromeButtonStyle(size: .row)).padding(10).frame(width: 190)
        }
    }
}
