import SwiftUI

struct FaviconView: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.75, weight: .light))
                    .foregroundStyle(.tertiary)
                    .frame(width: size, height: size)
            }
        }
        .animation(.easeIn(duration: 0.2), value: image != nil)
    }
}
