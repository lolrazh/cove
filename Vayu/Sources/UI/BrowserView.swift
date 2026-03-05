import SwiftUI

struct BrowserView: View {
    var body: some View {
        WebViewRepresentable(url: URL(string: "https://www.google.com")!)
            .frame(minWidth: 800, minHeight: 600)
    }
}
