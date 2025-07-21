import Foundation
import Combine

protocol BaseViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    var cancellables: Set<AnyCancellable> { get set }
    
    func handleError(_ error: Error)
    func clearError()
}

extension BaseViewModel {
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
}

// MARK: - Common View Model Base Class

class ViewModelBase: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    var cancellables = Set<AnyCancellable>()
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Combine Extensions

extension Publisher {
    func handleEvents(
        receiveStart: (() -> Void)? = nil,
        receiveOutput: ((Self.Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        handleEvents(
            receiveSubscription: { _ in receiveStart?() },
            receiveOutput: receiveOutput,
            receiveCompletion: receiveCompletion,
            receiveCancel: nil,
            receiveRequest: nil
        )
    }
    
    func mapToResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        map(Result.success)
            .catch { error in
                Just(Result.failure(error))
            }
            .eraseToAnyPublisher()
    }
    
    func shareReplay(_ count: Int = 1) -> AnyPublisher<Output, Failure> {
        share()
            .prefix(count)
            .eraseToAnyPublisher()
    }
}

// MARK: - Loading State Manager

class LoadingStateManager: ObservableObject {
    @Published private var loadingCount = 0
    
    var isLoading: Bool {
        loadingCount > 0
    }
    
    func startLoading() {
        DispatchQueue.main.async {
            self.loadingCount += 1
        }
    }
    
    func stopLoading() {
        DispatchQueue.main.async {
            self.loadingCount = max(0, self.loadingCount - 1)
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.loadingCount = 0
        }
    }
}