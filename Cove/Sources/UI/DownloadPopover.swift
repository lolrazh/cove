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
        .chromePanelSurface(.panel, cornerRadius: ChromeMetrics.panelCornerRadius, showsShadow: true)
    }

    private var header: some View {
        HStack {
            Text("Downloads")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if manager.items.contains(where: { $0.state != .downloading }) {
                Button("Clear") { manager.clearCompleted() }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .buttonStyle(ChromeButtonStyle(kind: .panelAction))
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
                        .font(.system(size: 12))
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
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    if !item.fileExtension.isEmpty {
                        Text(item.fileExtension)
                            .font(.system(size: 10, weight: .medium))
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
        .chromeInteractiveSurface(cornerRadius: ChromeMetrics.controlCornerRadius)
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
                    .stroke(Color.primary.opacity(0.08), lineWidth: 2)
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
                    .stroke(Color.primary.opacity(0.06), lineWidth: 2)
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
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.tertiary)
        case .completed:
            Text(item.totalBytes > 0 ? formatBytes(item.totalBytes) : "")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.tertiary)
        case .failed:
            Text("Failed")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .cancelled:
            Text("Cancelled")
                .font(.system(size: 10))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .tabAccessory))
        case .completed:
            Button { manager.revealInFinder(item) } label: {
                Image(systemName: ChromeSymbols.Navigation.search)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .tabAccessory))
            .help("Show in Finder")
        case .failed, .cancelled:
            Button { manager.remove(item) } label: {
                Image(systemName: ChromeSymbols.Tabs.close)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .tabAccessory))
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
