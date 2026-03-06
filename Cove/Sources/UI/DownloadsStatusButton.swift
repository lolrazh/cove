import SwiftUI

struct DownloadsStatusButton: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showDownloads = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { showDownloads.toggle() }) {
            VStack(spacing: 3) {
                downloadsIcon
                    .foregroundStyle(.primary)

                if downloadManager.hasActiveDownloads {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(ChromePalette.fieldStroke)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * downloadManager.overallProgress)
                                .animation(ChromeMotion.loading, value: downloadManager.overallProgress)
                        }
                    }
                    .frame(width: 18, height: 4)
                } else {
                    Spacer()
                        .frame(height: 4)
                }
            }
        }
        .buttonStyle(ChromeButtonStyle(kind: .toolbar))
        .popover(isPresented: $showDownloads, arrowEdge: .bottom) {
            DownloadPopover(manager: downloadManager)
        }
    }

    private var downloadsIcon: some View {
        let icon = Image(
            systemName: downloadManager.hasActiveDownloads
                ? ChromeSymbols.Navigation.downloadsActive
                : ChromeSymbols.Navigation.downloads
        )
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
