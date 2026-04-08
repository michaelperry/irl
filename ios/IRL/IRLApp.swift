import SwiftUI

@main
struct IRLApp: App {

    @StateObject private var authService = AuthService()
    @StateObject private var screenTimeService = ScreenTimeService()
    @StateObject private var postStore = PostStore()
    @AppStorage("irl_theme") private var selectedTheme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .onAppear {
                            screenTimeService.start()
                            LocationService.shared.requestPermission()
                        }
                        .onDisappear { screenTimeService.stop() }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authService)
            .environmentObject(screenTimeService)
            .environmentObject(postStore)
            .preferredColorScheme(selectedTheme.colorScheme)
        }
    }
}
