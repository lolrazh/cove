import Foundation

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let viewModel: WebViewModel
    @Published var isNewTabPage: Bool

    init(url: String? = nil) {
        self.id = UUID()
        if let url {
            self.viewModel = WebViewModel(initialURL: url)
            self.isNewTabPage = false
        } else {
            self.viewModel = WebViewModel(initialURL: nil)
            self.isNewTabPage = true
        }
    }
}
