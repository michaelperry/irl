import SwiftUI
import UIKit

final class IRLAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushService.shared.handleRegistration(token: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[push] APNs registration failed: \(error.localizedDescription)")
    }
}

@main
struct IRLApp: App {

    @UIApplicationDelegateAdaptor(IRLAppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var screenTimeService = ScreenTimeService()
    @StateObject private var postStore = PostStore()
    @AppStorage("irl_theme") private var selectedTheme: AppTheme = .system
    @AppStorage("irl_onboarding_completed") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authService.isAuthenticated {
                        if !onboardingCompleted || authService.didJustRegister {
                            OnboardingView(onComplete: {
                                onboardingCompleted = true
                                authService.didJustRegister = false
                            })
                        } else {
                            MainTabView()
                                .onAppear {
                                    screenTimeService.start()
                                    LocationService.shared.requestPermission()
                                    Task { await PushService.shared.requestAuthorizationAndRegister() }
                                }
                                .onDisappear { screenTimeService.stop() }
                        }
                    } else {
                        LoginView()
                    }
                }
                .environmentObject(authService)
                .environmentObject(screenTimeService)
                .environmentObject(postStore)
                // Force dark across the entire app: the IRL design language is "earth at night",
                // and the codebase mixes hardcoded white text with adaptive colors. Light-mode
                // rendering would need a real design pass before it can be re-enabled — until
                // then the appearance picker is hidden in Settings.
                .preferredColorScheme(.dark)

                // Lock screen overlay — requires Face ID to unlock
                if isLocked && authService.isAuthenticated {
                    LockScreenView {
                        isLocked = false
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    // Lock when going to background
                    isLocked = true
                    screenTimeService.stop()
                case .active:
                    if authService.isAuthenticated {
                        screenTimeService.start()
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Lock Screen

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var authenticating = false
    @State private var error: String?

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image("EarthBluMarble")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: IRLColors.oceanBlue.opacity(0.3), radius: 20)

                Text("irl")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(4)

                Text("Unlock to continue")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Button {
                    unlock()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 22))
                        Text("Unlock with Face ID")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 36)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
                    .frame(height: 44)
            }
        }
        .onAppear {
            unlock()
        }
    }

    private func unlock() {
        guard !authenticating else { return }
        authenticating = true
        Task {
            let context = LAContext()
            var nsError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError) else {
                error = nsError?.localizedDescription
                authenticating = false
                return
            }
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Verify it's you to continue using IRL"
                )
                if success {
                    onUnlock()
                }
            } catch {
                self.error = error.localizedDescription
            }
            authenticating = false
        }
    }
}

import LocalAuthentication
