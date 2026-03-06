import Foundation
import Combine

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let viewModel: WebViewModel
    @Published var isNewTabPage: Bool

    private var cancellables: Set<AnyCancellable> = []

    init(url: String? = nil) {
        self.id = UUID()
        if let url {
            self.viewModel = WebViewModel(initialURL: url)
            self.isNewTabPage = false
        } else {
            self.viewModel = WebViewModel(initialURL: nil)
            self.isNewTabPage = true
        }

        // Forward viewModel changes so views observing Tab re-render
        // when title, favicon, loading state, etc. change.
        viewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
