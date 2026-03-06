import SwiftUI

struct WindowChromeHost<Content: View>: View {
    let topBandHeight: CGFloat
    let controlsStyle: WindowChromeControlsStyle
    let content: Content

    @State private var titlebarHeight: CGFloat = 0

    init(
        topBandHeight: CGFloat,
        controlsStyle: WindowChromeControlsStyle,
        @ViewBuilder content: () -> Content
    ) {
        self.topBandHeight = topBandHeight
        self.controlsStyle = controlsStyle
        self.content = content()
    }

    var body: some View {
        content
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

        let centerlineOverflow = max(0, topBandHeight - titlebarHeight) / 2
        return titlebarHeight + centerlineOverflow
    }
}
