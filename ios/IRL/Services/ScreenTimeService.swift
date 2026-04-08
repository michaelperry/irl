import Foundation
import Combine

final class ScreenTimeService: ObservableObject {

    static let defaultLimit: TimeInterval = 3600 // 1 hour
    private static let warningThreshold: TimeInterval = 300 // 5 minutes
    private static let elapsedKey = "irl_screen_time_elapsed"
    private static let dateKey = "irl_screen_time_date"

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

    init(dailyLimit: TimeInterval = 3600) {
        self.dailyLimit = dailyLimit
        loadPersistedTime()
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
        persist()
    }

    private func tick() {
        guard elapsedSeconds < dailyLimit else {
            stop()
            return
        }
        elapsedSeconds += 1
        isWarningShown = remainingSeconds <= Self.warningThreshold && remainingSeconds > 0

        // Persist every 10 seconds
        if Int(elapsedSeconds) % 10 == 0 {
            persist()
        }
    }

    // MARK: - Persistence

    private func persist() {
        let today = todayString()
        UserDefaults.standard.set(elapsedSeconds, forKey: Self.elapsedKey)
        UserDefaults.standard.set(today, forKey: Self.dateKey)
    }

    private func loadPersistedTime() {
        let savedDate = UserDefaults.standard.string(forKey: Self.dateKey) ?? ""
        let today = todayString()

        if savedDate == today {
            // Same day — restore elapsed time
            elapsedSeconds = UserDefaults.standard.double(forKey: Self.elapsedKey)
        } else {
            // New day — reset
            elapsedSeconds = 0
            persist()
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
