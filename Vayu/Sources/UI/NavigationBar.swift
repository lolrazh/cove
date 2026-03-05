import SwiftUI

struct NavigationBar: View {
    @ObservedObject var viewModel: WebViewModel
    @State private var addressText: String = ""
    @State private var showHistory: Bool = false
    @FocusState private var isAddressFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Back
            navButton(
                icon: "chevron.left",
                enabled: viewModel.canGoBack,
                action: viewModel.goBack
            )

            // Forward
            navButton(
                icon: "chevron.right",
                enabled: viewModel.canGoForward,
                action: viewModel.goForward
            )

            // Reload / Stop
            navButton(
                icon: viewModel.isLoading ? "xmark" : "arrow.clockwise",
                enabled: true,
                action: { viewModel.isLoading ? viewModel.stopLoading() : viewModel.reload() }
            )

            // Address bar
            addressBar

            // History
            navButton(
                icon: "clock",
                enabled: true,
                action: { showHistory.toggle() }
            )
            .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                HistoryView(
                    onNavigate: { url in viewModel.loadURL(url) },
                    onDismiss: { showHistory = false }
                )
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onChange(of: viewModel.currentURL) { _, newURL in
            if !isAddressFocused {
                addressText = newURL
            }
        }
    }

    private var addressBar: some View {
        TextField("Search or enter URL", text: $addressText)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .regular, design: .default))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isAddressFocused
                            ? Color.accentColor.opacity(0.5)
                            : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .focused($isAddressFocused)
            .onSubmit {
                viewModel.loadURL(addressText)
                isAddressFocused = false
            }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? .primary : .tertiary)
        .disabled(!enabled)
        .contentShape(Rectangle())
    }
}
