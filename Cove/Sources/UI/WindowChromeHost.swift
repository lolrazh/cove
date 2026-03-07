import SwiftUI

struct WindowChromeHost<Content: View>: View {
    let content: Content

    @State private var titlebarHeight: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.titlebarHeight, titlebarHeight)
            .padding(.top, -chromeCompensationOffset)
            .background {
                WindowChromeAccessor(titlebarHeight: $titlebarHeight)
                    .allowsHitTesting(false)
            }
    }

    private var chromeCompensationOffset: CGFloat {
        guard titlebarHeight > 0 else { return 0 }
        return titlebarHeight
    }
}
