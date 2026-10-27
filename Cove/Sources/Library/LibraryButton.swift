import SwiftUI

/// Opens the Library: leading in the sidebar footer, where the Library takes
/// the tabs' place, and at the end of the navigation bar with tabs on top,
/// where it's a popover. While files download the button is a progress ring;
/// a finished download bounces it and leaves a dot until Downloads is seen.
struct LibraryButton: View {
    @ObservedObject private var library: LibraryModel
    @ObservedObject private var downloads: DownloadManager
    /// Where the popover opens; nil in the sidebar.
    private let popoverEdge: Edge?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(library: LibraryModel, popoverEdge: Edge? = nil) {
        self._library = ObservedObject(wrappedValue: library)
        self._downloads = ObservedObject(wrappedValue: library.downloads)
        self.popoverEdge = popoverEdge
    }

    var body: some View {
        Button(action: library.toggle) {
            icon
                .frame(width: ChromeMetrics.iconButtonSize, height: ChromeMetrics.iconButtonSize)
                .overlay(alignment: .topTrailing) {
                    if downloads.hasUnseenDownloads {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .padding(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(ChromeMotion.fade, value: downloads.hasActiveDownloads)
                .animation(ChromeMotion.appear, value: downloads.hasUnseenDownloads)
        }
        .buttonStyle(ChromeButtonStyle())
        .help("Library")
        .popover(isPresented: popoverBinding, arrowEdge: popoverEdge ?? .bottom) {
            LibraryView(model: library)
                .padding(10)
                .frame(width: 340, height: 460)
        }
    }

    /// The Library's symbol, or a download arrow inside a progress ring. The
    /// symbol stays put, so finishing can bounce it.
    private var icon: some View {
        let isDownloading = downloads.hasActiveDownloads

        return ZStack {
            Circle()
                .stroke(.fill.tertiary, lineWidth: 2)
            Circle()
                .trim(from: 0, to: downloads.overallProgress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(ChromeMotion.progress, value: downloads.overallProgress)
        }
        .frame(width: 18, height: 18)
        .opacity(isDownloading ? 1 : 0)
        .overlay {
            Image(systemName: isDownloading ? ChromeSymbols.Navigation.download : ChromeSymbols.Navigation.library)
                .font(isDownloading ? .caption.weight(.bold) : nil)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? 0 : downloads.completedCount)
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
