import SwiftUI

struct WindowChromeHost<Content: View>: View {
    @ObservedObject var tabManager: TabManager
    let isVisible: Bool
    let content: Content

    @State private var titlebarHeight: CGFloat = 0

    init(tabManager: TabManager, isVisible: Bool, @ViewBuilder content: () -> Content) {
        self._tabManager = ObservedObject(wrappedValue: tabManager)
        self.isVisible = isVisible
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.titlebarHeight, titlebarHeight)
            .padding(.top, -chromeCompensationOffset)
            .background {
                WindowChromeAccessor(
                    tabManager: tabManager,
                    isVisible: isVisible,
                    titlebarHeight: $titlebarHeight
                )
                .allowsHitTesting(false)
            }
    }

    private var chromeCompensationOffset: CGFloat {
        guard titlebarHeight > 0 else { return 0 }
        return titlebarHeight
    }
}
