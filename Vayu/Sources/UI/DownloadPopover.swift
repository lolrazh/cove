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
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if manager.items.contains(where: { $0.state != .downloading }) {
                Button("Clear") { manager.clearCompleted() }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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

struct DownloadItemRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager

    @State private var isHovering = false

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

                    Text(sizeText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    if item.state == .failed {
                        Text("— Failed")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.03) : .clear)
        .onHover { isHovering = $0 }
    }

    // Circle with file icon inside; during download the ring fills
    private var iconWithProgress: some View {
        ZStack {
            // Progress ring (background track always visible during download)
            if item.state == .downloading {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: item.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: item.progress)
            }

            // File icon — always shown
            Image(nsImage: item.fileIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
        }
        .frame(width: 28, height: 28)
    }

    private var sizeText: String {
        switch item.state {
        case .downloading:
            if item.totalBytes > 0 {
                return "\(formatBytes(item.bytesDownloaded)) / \(formatBytes(item.totalBytes))"
            } else if item.bytesDownloaded > 0 {
                return formatBytes(item.bytesDownloaded)
            }
            return ""
        case .completed:
            return item.totalBytes > 0 ? formatBytes(item.totalBytes) : ""
        case .failed, .cancelled:
            return item.bytesDownloaded > 0 ? formatBytes(item.bytesDownloaded) : ""
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.state {
        case .downloading:
            Button { manager.cancelDownload(item) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        case .completed:
            Button { manager.revealInFinder(item) } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        case .failed, .cancelled:
            Button { manager.remove(item) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
