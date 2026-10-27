import SwiftUI

/// A space's icon at the size of the text around it: its symbol, or its emoji.
struct SpaceIconView: View {
    let icon: SpaceIcon

    var body: some View {
        switch icon {
        case .symbol(let name) where icon == .dot:
            // A dot reads as Arc's space dot only when it's small.
            Image(systemName: name)
                .imageScale(.small)
                .scaleEffect(0.6)
        case .symbol(let name):
            Image(systemName: name)
        case .emoji(let emoji):
            Text(emoji)
        }
    }
}
