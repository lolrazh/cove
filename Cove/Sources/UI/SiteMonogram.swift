import SwiftUI

/// Stands in for a favicon that hasn't been fetched: the site's initial on a
/// tile in a color derived from its name, so a site keeps its color across
/// launches and a row of fallbacks doesn't read as one gray blur.
struct SiteMonogram: View {
    let host: String
    let size: CGFloat

    var body: some View {
        Text(host.prefix(1).uppercased())
            .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .rect(cornerRadius: size * 0.22))
    }

    /// `hashValue` is salted per launch, so the hue comes from a stable hash,
    /// scrambled so that hosts differing in one letter land on different hues.
    private var color: Color {
        let hash = host.unicodeScalars.reduce(UInt32(2166136261)) { ($0 ^ $1.value) &* 16777619 }
        let scrambled = (hash ^ (hash >> 15)) &* 2246822519
        return Color(hue: Double(scrambled % 360) / 360, saturation: 0.5, brightness: 0.78)
    }
}
