import SwiftUI

struct DownloadsStatusButton: View {
    @ObservedObject private var downloadManager: DownloadManager
    @State private var showDownloads = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(downloadManager: DownloadManager) {
        self._downloadManager = ObservedObject(wrappedValue: downloadManager)
    }

    var body: some View {
        Button(action: { showDownloads.toggle() }) {
            ZStack(alignment: .bottom) {
                downloadsIcon
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if downloadManager.hasActiveDownloads {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.fill.tertiary)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * downloadManager.overallProgress)
                                .animation(.linear(duration: 0.24), value: downloadManager.overallProgress)
                        }
                    }
                    .frame(width: 18, height: 4)
                    .padding(.bottom, 3)
                }
            }
            .frame(
                width: ChromeMetrics.iconButtonSize,
                height: ChromeMetrics.iconButtonSize
            )
        }
        .buttonStyle(ChromeButtonStyle())
        .popover(isPresented: $showDownloads, arrowEdge: .bottom) {
            DownloadPopover(manager: downloadManager)
        }
    }

    private var downloadsIcon: some View {
        let icon = Image(systemName: ChromeSymbols.Navigation.downloads)
            .font(.system(size: 13, weight: .medium))

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: downloadManager.items.count)
            }
        }
    }
}
