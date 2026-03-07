import SwiftUI

struct WindowChromeHost<Content: View>: View {
    let controlsStyle: WindowChromeControlsStyle
    let content: Content

    @State private var titlebarHeight: CGFloat = 0

    init(
        controlsStyle: WindowChromeControlsStyle,
        @ViewBuilder content: () -> Content
    ) {
        self.controlsStyle = controlsStyle
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.titlebarHeight, titlebarHeight)
            .padding(.top, -chromeCompensationOffset)
            .background {
                WindowChromeAccessor(
                    controlsStyle: controlsStyle,
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
