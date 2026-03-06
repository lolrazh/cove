import Foundation
import Combine

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let viewModel: WebViewModel
    @Published var isNewTabPage: Bool

    private var cancellables: Set<AnyCancellable> = []

    init(url: String? = nil, showsStartPage: Bool = true) {
        self.id = UUID()
        if showsStartPage {
            self.viewModel = WebViewModel(initialURL: nil)
            self.isNewTabPage = true
        } else if let url {
            self.viewModel = WebViewModel(initialURL: url)
            self.isNewTabPage = false
        } else {
            self.viewModel = WebViewModel(initialURL: nil)
            self.isNewTabPage = false
        }

        // Forward viewModel changes so views observing Tab re-render
        // when title, favicon, loading state, etc. change.
        viewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
