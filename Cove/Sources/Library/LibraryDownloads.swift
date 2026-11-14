import SwiftUI

struct LibraryDownloads: View {
    @ObservedObject var manager: DownloadManager

    var body: some View {
        LibraryToolbar {
            Spacer(minLength: 0)
            Button("Clear") { manager.clearCompleted() }
                .buttonStyle(.borderless)
                .disabled(!manager.items.contains { $0.state != .downloading })
                .help("Clear finished downloads from this list. Keep the files.")
        }
        DownloadList(manager: manager)
    }
}

struct DownloadList: View {
    @ObservedObject var manager: DownloadManager

    var body: some View {
        LibraryList(isEmpty: manager.items.isEmpty, emptyText: "No downloads yet") {
            ForEach(manager.items) { item in
                DownloadRow(item: item, manager: manager)
            }
        }
        .onAppear {
            manager.refreshFiles()
            manager.markDownloadsSeen()
        }
        .onChange(of: manager.hasUnseenDownloads) { manager.markDownloadsSeen() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.refreshFiles()
        }
    }
}

private struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canOpen: Bool { item.state == .completed && item.fileExists }
    private var canRetry: Bool { item.state != .downloading && item.canRestart }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if canOpen {
                    Button { manager.open(item) } label: { fileLabel }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.filename)
                        .accessibilityValue(status)
                } else {
                    fileLabel
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.filename)
                        .accessibilityValue(status)
                }
            }
            .help(item.detail ?? item.filename)
            actionButton.frame(width: 24)
        }
        .padding(.horizontal, 6)
        .frame(height: 48)
        .background {
            ConcentricRectangle.chrome(minimum: ChromeRadius.tab)
                .fill(ChromePalette.hover).opacity(isHovered ? 1 : 0)
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            if canOpen {
                Button("Open") { manager.open(item) }
                Button("Show in Finder") { manager.revealInFinder(item) }
            }
            if item.state == .downloading {
                Button("Cancel Download") { manager.cancelDownload(item) }
            } else {
                if canRetry { Button("Download Again") { manager.retry(item) } }
                Button("Remove from List") { manager.remove(item) }
            }
            if let url = item.sourceURL, ["https", "http"].contains(url.scheme) {
                Divider()
                Button("Copy Download Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
        }
    }

    private var fileLabel: some View {
        HStack(spacing: 8) {
            Image(nsImage: item.fileIcon)
                .resizable().interpolation(.high)
                .frame(width: 22, height: 22)
                .opacity(item.state == .cancelled ? 0.5 : 1)
                .frame(width: 24, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.callout.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                Group {
                    if item.state == .downloading {
                        DownloadProgressText(completed: item.bytesDownloaded, total: item.totalBytes,
                                             remainingSeconds: item.remainingSeconds)
                    } else {
                        Text(status).monospacedDigit().lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                progressTrack.frame(height: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            Capsule().fill(.secondary.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule().fill(.tint)
                        .frame(width: geometry.size.width * item.progress)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: item.progress)
                }
        }
        .opacity(item.state == .downloading && item.totalBytes > 0 ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var status: String {
        switch item.state {
        case .downloading:
            return DownloadProgressSize(total: item.totalBytes).description(completed: item.bytesDownloaded,
                                                                           remainingSeconds: item.remainingSeconds)
        case .completed:
            if !item.fileExists { return "File moved or deleted" }
            if let detail = item.detail { return detail }
            return DownloadProgressSize(total: max(0, item.totalBytes)).formattedTotal
        case .failed:
            if !canRetry { return "Download failed" }
            return item.detail == "Interrupted" ? "Interrupted — try again" : "Download failed — try again"
        case .cancelled: return "Cancelled"
        }
    }

    @ViewBuilder private var actionButton: some View {
        if item.state == .downloading {
            accessory("xmark", label: "Cancel Download") { manager.cancelDownload(item) }
        } else if canOpen {
            accessory("magnifyingglass", label: "Show in Finder") { manager.revealInFinder(item) }
        } else if canRetry {
            accessory("arrow.clockwise", label: "Retry Download") { manager.retry(item) }
        } else {
            accessory("xmark", label: "Remove from List") { manager.remove(item) }
        }
    }

    private func accessory(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).foregroundStyle(.secondary) }
            .buttonStyle(.libraryAccessory)
            .accessibilityLabel(label).help(label)
    }

}
