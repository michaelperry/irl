import Foundation
import Combine

@MainActor
final class ScreenTimeService: ObservableObject {

    static let defaultLimit: TimeInterval = 3600 // 1 hour
    private static let warningThreshold: TimeInterval = 300 // 5 minutes

    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var isWarningShown = false

    let dailyLimit: TimeInterval

    var remainingSeconds: TimeInterval {
        max(dailyLimit - elapsedSeconds, 0)
    }

    var remainingFormatted: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard dailyLimit > 0 else { return 1 }
        return min(elapsedSeconds / dailyLimit, 1)
    }

    private var timer: Timer?

    init(dailyLimit: TimeInterval = ScreenTimeService.defaultLimit) {
        self.dailyLimit = dailyLimit
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard elapsedSeconds < dailyLimit else {
            stop()
            return
        }
        elapsedSeconds += 1
        isWarningShown = remainingSeconds <= Self.warningThreshold && remainingSeconds > 0
    }
}
