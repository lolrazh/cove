import Foundation
import Combine

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let viewModel: WebViewModel
    @Published var isNewTabPage: Bool

    private var cancellables: Set<AnyCancellable> = []

    init(
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = true,
        onOpenInNewTab: (@MainActor (URLRequest) -> Void)? = nil
    ) {
        self.id = UUID()
        if showsStartPage {
            self.viewModel = WebViewModel(onOpenInNewTab: onOpenInNewTab)
            self.isNewTabPage = true
        } else if let initialRequest {
            self.viewModel = WebViewModel(
                initialRequest: initialRequest,
                onOpenInNewTab: onOpenInNewTab
            )
            self.isNewTabPage = false
        } else if let initialURL {
            self.viewModel = WebViewModel(
                initialURL: initialURL,
                onOpenInNewTab: onOpenInNewTab
            )
            self.isNewTabPage = false
        } else {
            self.viewModel = WebViewModel(onOpenInNewTab: onOpenInNewTab)
            self.isNewTabPage = false
        }

        // Forward viewModel changes so views observing Tab re-render
        // when title, favicon, loading state, etc. change.
        viewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
