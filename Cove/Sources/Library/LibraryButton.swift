import SwiftUI

/// Opens the Library: leading in the sidebar footer, where the Library takes
/// the tabs' place, and at the end of the navigation bar with tabs on top,
/// where it's a popover. Downloads have a separate button beside the address bar.
struct LibraryButton: View {
    @ObservedObject private var library: LibraryModel
    /// Where the popover opens; nil in the sidebar.
    private let popoverEdge: Edge?

    init(library: LibraryModel, popoverEdge: Edge? = nil) {
        self._library = ObservedObject(wrappedValue: library)
        self.popoverEdge = popoverEdge
    }

    var body: some View {
        Button(action: library.toggle) {
            Image(systemName: ChromeSymbols.Navigation.library)
        }
        .buttonStyle(ChromeButtonStyle(restingOpacity: popoverEdge == nil ? 0.6 : 1))
        .accessibilityLabel("Library")
        .help("Library — downloads, closed tabs, and history")
        .popover(isPresented: popoverBinding, arrowEdge: popoverEdge ?? .bottom) {
            LibraryView(model: library)
                .padding(10)
                .frame(width: 340, height: 460)
        }
    }

    /// The navigation bar stays in the window, collapsed, with tabs in the
    /// sidebar, so its button presents only with tabs on top.
    private var popoverBinding: Binding<Bool> {
        Binding {
            popoverEdge != nil && library.showsPopover
        } set: { isPresented in
            if !isPresented { library.dismiss() }
        }
    }
}
