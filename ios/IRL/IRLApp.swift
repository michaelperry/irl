import SwiftUI

@main
struct IRLApp: App {

    @StateObject private var authService = AuthService()
    @StateObject private var screenTimeService = ScreenTimeService()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .onAppear { screenTimeService.start() }
                        .onDisappear { screenTimeService.stop() }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authService)
            .environmentObject(screenTimeService)
        }
    }
}
