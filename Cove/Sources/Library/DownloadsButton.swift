import SwiftUI

/// One stable header slot. Restored history does not reveal the session indicator.
struct DownloadsButton: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var manager: DownloadManager
    let colorScheme: ColorScheme
    var isVisible = true
    @State private var highlight = false
    @State private var highlightTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if manager.hasSessionDownloads {
                downloadButton
            } else {
                Color.clear.frame(width: ChromeMetrics.iconButtonSize, height: ChromeMetrics.iconButtonSize)
                    .accessibilityHidden(true)
            }
        }
        .anchorPreference(key: DownloadButtonAnchor.self, value: .bounds) { isVisible ? $0 : nil }
    }

    private var downloadButton: some View {
        Button { library.downloadsPresented.toggle() } label: {
            ZStack {
                Circle().stroke(.secondary.opacity(0.18), lineWidth: 1.5)
                    .opacity(manager.hasActiveDownloads ? 1 : 0)
                Circle()
                    .trim(from: 0, to: manager.overallProgress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(manager.hasActiveDownloads ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: manager.overallProgress)
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(width: 18, height: 18)
            .symbolEffect(.bounce, options: .speed(1.5), value: reduceMotion ? 0 : library.downloadPulse)
            .background {
                Circle().fill(.tint.opacity(0.25))
                    .frame(width: 30, height: 30)
                    .blur(radius: 4)
                    .opacity(highlight ? 1 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if manager.hasUnseenDownloads {
                    Circle().fill(.tint).frame(width: 5, height: 5).offset(x: 3, y: -2)
                }
            }
        }
        .buttonStyle(ChromeButtonStyle())
        .accessibilityLabel("Downloads")
        .accessibilityValue(manager.hasActiveDownloads ? "Downloading" : manager.hasUnseenDownloads ? "New downloads" : "")
        .help("Downloads (⇧⌘J)")
        .onChange(of: library.downloadPulse) {
            guard isVisible else { return }
            highlightTask?.cancel()
            highlightTask = Task { @MainActor in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { highlight = true }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 3)) { highlight = false }
            }
        }
        .onDisappear { highlightTask?.cancel(); highlight = false }
        .popover(isPresented: Binding(
            get: { isVisible && library.downloadsPresented },
            set: { if isVisible { library.downloadsPresented = $0 } }
        ), arrowEdge: .bottom) {
            VStack(spacing: 6) {
                HStack {
                    Text("Downloads").font(.callout.weight(.semibold))
                    Spacer()
                    Button("Clear") { manager.clearCompleted() }
                        .buttonStyle(.borderless)
                        .disabled(!manager.items.contains { $0.state != .downloading })
                        .help("Clear finished downloads from this list. Keep the files.")
                }
                .padding(.horizontal, 6)
                .frame(height: 28)
                DownloadList(manager: manager)
                    .frame(height: manager.items.isEmpty ? 64 : min(336, CGFloat(manager.items.count) * 50 + 8))
            }
            .padding(10)
            .frame(width: 320)
            .environment(\.colorScheme, colorScheme)
        }

        .accessibilityHidden(!manager.hasSessionDownloads || !isVisible)
    }
}
