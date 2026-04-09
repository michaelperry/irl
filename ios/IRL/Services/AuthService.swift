import Combine
import Foundation
import LocalAuthentication
import UIKit

final class AuthService: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var authError: String?
    @Published private(set) var userId: String?
    @Published private(set) var isLoading = false

    func authenticate() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = error?.localizedDescription ?? "Biometric authentication unavailable."
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to IRL"
            )

            guard success else {
                authError = "Authentication failed."
                return
            }

            authError = nil
            isLoading = true

            // Get or create a stable biometric key ID for this device
            let biometricKeyId = getOrCreateBiometricKeyId()

            // Try login first, then register if new user
            do {
                let response = try await APIClient.shared.login(biometricKeyId: biometricKeyId)
                handleAuthSuccess(response: response)
            } catch let apiError as APIError {
                // If user not found, register
                if case .serverError(let code, _) = apiError, code == 404 {
                    do {
                        let displayName = UserDefaults.standard.string(forKey: "irl_display_name") ?? "User"
                        let response = try await APIClient.shared.register(
                            biometricKeyId: biometricKeyId,
                            displayName: displayName
                        )
                        handleAuthSuccess(response: response)
                        print("[IRL] New user registered: \(response.user?.id ?? "?")")
                    } catch {
                        authError = "Failed to create account: \(error.localizedDescription)"
                        isLoading = false
                    }
                } else {
                    authError = "Login failed: \(apiError.localizedDescription)"
                    isLoading = false
                }
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        isAuthenticated = false
        userId = nil
        // Keep Keychain data so they can log back in
        // Only clear token, not biometric key ID
        KeychainService.delete(key: KeychainService.authTokenKey)
    }

    func deleteAccountData() {
        isAuthenticated = false
        userId = nil
        KeychainService.clearAll()
    }

    // MARK: - Private

    private func handleAuthSuccess(response: APIClient.AuthResponse) {
        // Store token and user ID in Keychain (survives app deletion)
        KeychainService.save(key: KeychainService.authTokenKey, value: response.token)

        let id = response.user?.id ?? response.userId ?? ""
        KeychainService.save(key: KeychainService.userIdKey, value: id)

        userId = id
        isAuthenticated = true
        isLoading = false

        print("[IRL] Auth success, userId: \(id)")
    }

    private func getOrCreateBiometricKeyId() -> String {
        // Check if we already have a biometric key ID in Keychain
        if let existing = KeychainService.load(key: KeychainService.biometricKeyIdKey) {
            return existing
        }

        // Generate a new stable identifier for this device+person
        // This persists in Keychain across app installs
        let newId = UUID().uuidString
        KeychainService.save(key: KeychainService.biometricKeyIdKey, value: newId)
        return newId
    }
}
