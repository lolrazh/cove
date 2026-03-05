import Foundation

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let viewModel: WebViewModel

    init(url: String = "https://www.google.com") {
        self.id = UUID()
        self.viewModel = WebViewModel(initialURL: url)
    }
}
