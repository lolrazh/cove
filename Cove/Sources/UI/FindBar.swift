import SwiftUI

/// The find bar, floating in the page's top-trailing corner like Arc's: a
/// field, a word when there's no match, previous and next, and close. Return
/// and Shift-Return step through matches; Escape closes it.
struct FindBar: View {
    @ObservedObject var find: FindInPage
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if find.isPresented {
                bar.transition(transition)
            }
        }
        .padding(ChromeMetrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(reduceMotion ? ChromeMotion.hover : ChromeMotion.commandBar, value: find.isPresented)
    }

    private var bar: some View {
        HStack(spacing: 2) {
            field
            Button(action: find.findPrevious) {
                Image(systemName: "chevron.up")
            }
            .help("Previous Match")
            Button(action: find.findNext) {
                Image(systemName: "chevron.down")
            }
            .help("Next Match")
            Button(action: find.dismiss) {
                Image(systemName: ChromeSymbols.Tabs.close)
            }
            .help("Done")
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory(side: 24)))
        .padding(4)
        .chromeFloatingSurface(minimumRadius: ChromeRadius.tab)
        .onExitCommand(perform: find.dismiss)
        .onAppear { isFocused = true }
        .onChange(of: find.focusRequests) { isFocused = true }
    }

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: ChromeSymbols.Navigation.search)
                .foregroundStyle(.secondary)
            TextField("Find on Page", text: $find.query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(find.findNext)
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    find.findPrevious()
                    return .handled
                }
            if !find.isFound {
                Text("Not Found")
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .frame(width: 220, height: 24)
        .chromeFieldStyle(focused: false, minimumRadius: ChromeRadius.accessory)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity)
    }
}
