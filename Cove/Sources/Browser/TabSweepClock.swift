import Combine
import Foundation

/// Says when a window's idle tabs should be looked at: every minute for the
/// idle settings, and at once when the system runs short of memory.
@MainActor
final class TabSweepClock {
    /// Each tick says whether memory is short, when everything that can sleep
    /// should.
    let ticks: AnyPublisher<Bool, Never>

    private let warnings = PassthroughSubject<Bool, Never>()
    private let memoryPressure: DispatchSourceMemoryPressure

    init(every interval: TimeInterval = 60) {
        let minutes = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in false }
        ticks = minutes.merge(with: warnings).eraseToAnyPublisher()

        memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        memoryPressure.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.warnings.send(true) }
        }
        memoryPressure.activate()
    }

    deinit {
        memoryPressure.cancel()
    }
}
