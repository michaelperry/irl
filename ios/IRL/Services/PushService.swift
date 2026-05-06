import Foundation
import UIKit

/// Handles APNs token registration + uploading the token to the backend.
///
/// Wire-up: in your AppDelegate (or @UIApplicationDelegateAdaptor), forward
/// `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` to
/// `PushService.shared.handleRegistration(token:)`.
final class PushService: NSObject {

    static let shared = PushService()
    private override init() {}

    private let deviceIdKey = "irl_apns_device_id"

    /// Ask the user for permission and register for remote notifications.
    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[push] auth request failed: \(error.localizedDescription)")
        }
    }

    /// Forward the token bytes from your AppDelegate.
    func handleRegistration(token: Data) {
        let hex = token.map { String(format: "%02.2hhx", $0) }.joined()
        let deviceId = stableDeviceId()

        Task {
            do {
                try await APIClient.shared.registerAPNsToken(
                    token: hex,
                    deviceId: deviceId,
                    environment: apnsEnvironment
                )
            } catch {
                print("[push] token upload failed: \(error.localizedDescription)")
            }
        }
    }

    private var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private func stableDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: deviceIdKey)
        return new
    }
}
