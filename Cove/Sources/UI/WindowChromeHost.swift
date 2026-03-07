import SwiftUI

struct WindowChromeHost<Content: View>: View {
    let isVisible: Bool
    let content: Content

    @State private var titlebarHeight: CGFloat = 0

    init(isVisible: Bool, @ViewBuilder content: () -> Content) {
        self.isVisible = isVisible
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.titlebarHeight, titlebarHeight)
            .padding(.top, -chromeCompensationOffset)
            .background {
                WindowChromeAccessor(
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
