import SwiftUI

struct DownloadPopover: View {
    @ObservedObject var manager: DownloadManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            downloadList
        }
        .frame(width: 300, height: min(CGFloat(max(manager.items.count, 1)) * 56 + 40, 360))
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
            fileIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                statusView
            }

            Spacer()

            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.03) : .clear)
        .onHover { isHovering = $0 }
    }

    private var fileIcon: some View {
        Group {
            switch item.state {
            case .downloading:
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: item.progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 20, height: 20)
                .animation(.linear(duration: 0.3), value: item.progress)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 18))
            case .cancelled:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
            }
        }
        .frame(width: 24)
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.state {
        case .downloading:
            ProgressView(value: item.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
        case .completed:
            Text("Completed")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .failed:
            Text("Failed")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        case .cancelled:
            Text("Cancelled")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
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
}
