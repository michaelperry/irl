import Foundation
import LocalAuthentication

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var authError: String?

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
            isAuthenticated = success
            if success { authError = nil }
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        isAuthenticated = false
    }
}
