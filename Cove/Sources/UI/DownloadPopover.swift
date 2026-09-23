import SwiftUI

struct DownloadPopover: View {
    @ObservedObject var manager: DownloadManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            downloadList
        }
        .frame(width: 300, height: min(CGFloat(max(manager.items.count, 1)) * 60 + 40, 360))
    }

    private var header: some View {
        HStack {
            Text("Downloads")
                .font(.headline)
            Spacer()
            if manager.items.contains(where: { $0.state != .downloading }) {
                Button("Clear") { manager.clearCompleted() }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var downloadList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if manager.items.isEmpty {
                    Text("No downloads")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(manager.items) { item in
                        DownloadItemRow(item: item, manager: manager)
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }
}

private struct DownloadItemRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager

    var body: some View {
        HStack(spacing: 10) {
            iconWithProgress

            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    if !item.fileExtension.isEmpty {
                        Text(item.fileExtension)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    statusText
                }
            }

            Spacer()

            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .chromeHoverSurface()
        .contentShape(Rectangle())
        .onTapGesture { openFile() }
    }

    // File icon inside a progress ring. Icon always visible;
    // ring fills during download, greyed out when cancelled/failed.
    private var iconWithProgress: some View {
        ZStack {
            switch item.state {
            case .downloading:
                Circle()
                    .stroke(.fill.tertiary, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: item.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: item.progress)
            case .failed:
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
            case .cancelled:
                Circle()
                    .stroke(.fill.quaternary, lineWidth: 2)
            case .completed:
                EmptyView()
            }

            Image(nsImage: item.fileIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .opacity(item.state == .cancelled ? 0.4 : 1)
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var statusText: some View {
        switch item.state {
        case .downloading:
            Text(downloadSizeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        case .completed:
            Text(item.totalBytes > 0 ? formatBytes(item.totalBytes) : "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        case .failed:
            Text("Failed")
                .font(.caption)
                .foregroundStyle(.red)
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }

    private var downloadSizeText: String {
        if item.totalBytes > 0 {
            return "\(formatBytes(item.bytesDownloaded)) / \(formatBytes(item.totalBytes))"
        } else if item.bytesDownloaded > 0 {
            return formatBytes(item.bytesDownloaded)
        }
        return ""
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.state {
        case .downloading:
            Button { manager.cancelDownload(item) } label: {
                Image(systemName: ChromeSymbols.Tabs.close)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory()))
        case .completed:
            Button { manager.revealInFinder(item) } label: {
                Image(systemName: ChromeSymbols.Navigation.search)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory()))
            .help("Show in Finder")
        case .failed, .cancelled:
            Button { manager.remove(item) } label: {
                Image(systemName: ChromeSymbols.Tabs.close)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory()))
        }
    }

    private func openFile() {
        guard item.state == .completed, let url = item.fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }
}
