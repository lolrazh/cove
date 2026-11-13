import SwiftUI

/// Downloads stay beside the page. Opening the list never replaces the tabs.
struct DownloadsButton: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var manager: DownloadManager
    let colorScheme: ColorScheme
    @Environment(\.controlActiveState) private var controlState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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
        .popover(isPresented: $library.downloadsPresented, arrowEdge: .bottom) {
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
        .onChange(of: manager.presentationRequest) {
            // A background window or profile must not take focus.
            if controlState == .key { library.downloadsPresented = true }
        }
    }
}
