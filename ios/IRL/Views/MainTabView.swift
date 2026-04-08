import SwiftUI

struct MainTabView: View {

    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("Post", systemImage: "camera.fill")
                }
                .tag(0)

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "photo.stack.fill")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("You", systemImage: "globe.americas.fill")
                }
                .tag(2)
        }
        .tint(IRLColors.oceanBlue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .environmentObject(ScreenTimeService())
        .environmentObject(PostStore())
}
