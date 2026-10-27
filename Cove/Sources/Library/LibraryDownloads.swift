import SwiftUI

/// Downloads, newest first. Clicking a finished one opens it.
struct LibraryDownloads: View {
    @ObservedObject var manager: DownloadManager

    var body: some View {
        LibraryToolbar {
            Spacer(minLength: 0)

            Button("Clear") { manager.clearCompleted() }
                .buttonStyle(.borderless)
                .disabled(!manager.items.contains { $0.state != .downloading })
        }

        LibraryList(isEmpty: manager.items.isEmpty, emptyText: "No downloads") {
            ForEach(manager.items) { item in
                LibraryDownloadRow(item: item, manager: manager)
            }
        }
        // Looking at Downloads is what clears the Library button's dot.
        .onAppear(perform: manager.markDownloadsSeen)
        .onChange(of: manager.hasUnseenDownloads) { manager.markDownloadsSeen() }
    }
}

private struct LibraryDownloadRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager

    var body: some View {
        LibraryRow(title: item.filename, action: { manager.open(item) }) {
            iconWithProgress
        } detail: {
            statusText
        } accessory: { _ in
            actionButton
        }
        .contextMenu {
            if item.state == .completed {
                Button("Open") { manager.open(item) }
                Button("Show in Finder") { manager.revealInFinder(item) }
                Divider()
            }
            if item.state == .downloading {
                Button("Cancel Download") { manager.cancelDownload(item) }
            } else {
                Button("Remove from List") { manager.remove(item) }
            }
        }
    }

    /// The file's icon inside a ring that fills while it downloads, red when
    /// it failed and faint when cancelled.
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
                    .animation(ChromeMotion.progress, value: item.progress)
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
                .frame(width: item.state == .completed ? 22 : 14, height: item.state == .completed ? 22 : 14)
                .opacity(item.state == .cancelled ? 0.4 : 1)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch item.state {
        case .downloading:
            Text(downloadSizeText)
                .monospacedDigit()
        case .completed:
            Text(item.totalBytes > 0 ? formatBytes(item.totalBytes) : item.fileExtension)
                .monospacedDigit()
        case .failed:
            Text("Failed")
                .foregroundStyle(.red)
        case .cancelled:
            Text("Cancelled")
        }
    }

    private var downloadSizeText: String {
        if item.totalBytes > 0 {
            return "\(formatBytes(item.bytesDownloaded)) of \(formatBytes(item.totalBytes))"
        } else if item.bytesDownloaded > 0 {
            return formatBytes(item.bytesDownloaded)
        }
        return "Starting…"
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.state {
        case .downloading:
            accessory(ChromeSymbols.Tabs.close, help: "Cancel Download") { manager.cancelDownload(item) }
        case .completed:
            accessory(ChromeSymbols.Navigation.search, help: "Show in Finder") { manager.revealInFinder(item) }
        case .failed, .cancelled:
            accessory(ChromeSymbols.Tabs.close, help: "Remove from List") { manager.remove(item) }
        }
    }

    private func accessory(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.libraryAccessory)
        .help(help)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }
}
