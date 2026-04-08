import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var screenTimeService: ScreenTimeService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Avatar
                    Circle()
                        .fill(IRLColors.earthGradient)
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 24)

                    // Stats
                    HStack(spacing: 48) {
                        StatColumn(value: "128", label: "Friends")
                        StatColumn(value: "64", label: "Posts")
                        StatColumn(value: "42", label: "Likes")
                    }

                    // Screen time card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundStyle(IRLColors.oceanBlue)
                            Text("Screen Time Remaining")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Spacer()
                        }

                        ProgressView(value: 1 - screenTimeService.progress)
                            .tint(progressColor)

                        Text(screenTimeService.remainingFormatted)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(progressColor)

                        if screenTimeService.isWarningShown {
                            Text("Less than 5 minutes remaining. Time to go outside.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Sign out
                    Button(role: .destructive) {
                        authService.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Open settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(IRLColors.oceanBlue)
                    }
                }
            }
        }
    }

    private var progressColor: Color {
        if screenTimeService.progress > 0.9 {
            return .red
        } else if screenTimeService.progress > 0.75 {
            return .orange
        } else {
            return IRLColors.earthGreen
        }
    }
}

// MARK: - Stat Column

private struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .environmentObject(ScreenTimeService())
}
