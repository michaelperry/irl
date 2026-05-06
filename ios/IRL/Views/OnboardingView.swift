import SwiftUI
import UIKit

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step: Int = 0
    private let totalSteps = 5

    /// Onboarding is a brand hero — always dark, regardless of system or app theme.
    private static let onboardingBackground = Color(red: 0.04, green: 0.05, blue: 0.10)

    var body: some View {
        ZStack {
            Self.onboardingBackground.ignoresSafeArea()

            // Step content
            Group {
                switch step {
                case 0: HeroStep()
                case 1: PillarsStep()
                case 2: VerifiedRealStep()
                case 3: InviteStep(onSkip: advance, onSent: advance)
                case 4: PermissionsStep(onDone: complete)
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .id(step)

            // Progress + nav
            VStack {
                StepDots(current: step, total: totalSteps)
                    .padding(.top, 16)
                Spacer()
                if step < 3 {
                    Button { advance() } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "irl_onboarding_completed")
        onComplete()
    }
}

// MARK: - Step indicator

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.white : .white.opacity(0.2))
                    .frame(width: i == current ? 24 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
            }
        }
    }
}

// MARK: - 1. Hero

private struct HeroStep: View {
    @State private var glow = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [IRLColors.oceanBlue.opacity(0.35), .clear],
                        center: .center, startRadius: 50, endRadius: 200
                    ))
                    .frame(width: 360, height: 360)
                    .blur(radius: 20)
                    .scaleEffect(glow ? 1.05 : 1.0)

                EarthView(autoRotate: true)
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
                    .shadow(color: IRLColors.oceanBlue.opacity(0.3), radius: 40)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            Spacer().frame(height: 8)

            VStack(spacing: 12) {
                Text("A smaller internet.")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Made for the 50 people\nwho actually matter.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer().frame(height: 80) // leave room for nav
        }
    }
}

// MARK: - 2. Three Pillars

private struct PillarsStep: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text("Our promise.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Three things we'll never compromise on.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 4)

            VStack(spacing: 12) {
                PillarCard(
                    emoji: "🌍",
                    title: "Real-life sized",
                    text: "Capped at 50 friends. That's how many faces you actually know."
                )
                PillarCard(
                    emoji: "🛡",
                    title: "No manipulation",
                    text: "Chronological. No ads. No tracking. No algorithm picking what you see."
                )
                PillarCard(
                    emoji: "🔑",
                    title: "Your data, your keys",
                    text: "End-to-end encrypted. Your keys live on this device — we literally can't read your stuff."
                )
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer().frame(height: 90)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PillarCard: View {
    let emoji: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji).font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - 3. Verified Real

private struct VerifiedRealStep: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 80)

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(IRLColors.earthGreen)
                Text("Verified Real")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("We don't lie about what's real.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 10) {
                BadgeRow(icon: "checkmark.seal.fill", color: IRLColors.earthGreen,
                         label: "Verified Real", note: "Captured in IRL's camera. We saw it happen.")
                BadgeRow(icon: "photo.badge.checkmark", color: .yellow,
                         label: "Camera Roll", note: "From your photos. EXIF data still intact.")
                BadgeRow(icon: "exclamationmark.triangle.fill", color: .orange,
                         label: "Unverified", note: "We can't prove this one's real.")
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer().frame(height: 90)
        }
    }
}

private struct BadgeRow: View {
    let icon: String
    let color: Color
    let label: String
    let note: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(note).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 4. Invite

private struct InviteStep: View {
    var onSkip: () -> Void
    var onSent: () -> Void

    @State private var invites: [Invite] = []
    @State private var loading = false
    @State private var presentShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            VStack(spacing: 8) {
                Text("Invite 5. Unlock 5.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Bring 5 real-life friends.\nWe'll unlock 5 more spots in your circle.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            DotsGrid(filled: 0, total: 50, ghost: 5, redeemedBonus: redeemedCount)
                .padding(.horizontal, 32)
                .padding(.vertical, 8)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task { await mintAndShare() }
                } label: {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.black) }
                        Text(loading ? "Loading…" : "Send Invites")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .disabled(loading)

                Button("Skip for now", action: onSkip)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 36)
        }
        .task { await loadInvites() }
        .sheet(isPresented: $presentShare) {
            ActivityView(items: shareItems)
        }
    }

    private var redeemedCount: Int {
        invites.filter { $0.isRedeemed }.count
    }

    private func loadInvites() async {
        do {
            invites = try await APIClient.shared.listMyInvites()
        } catch {
            print("[IRL] listMyInvites failed: \(error.localizedDescription)")
        }
    }

    private func mintAndShare() async {
        loading = true
        defer { loading = false }
        do {
            let minted = try await APIClient.shared.mintInvites(count: 5)
            invites = minted
            let codes = minted.filter { !$0.isRedeemed }.prefix(5).map { $0.code }
            let body = inviteShareText(codes: Array(codes))
            shareItems = [body]
            onSent()
            presentShare = true
        } catch {
            print("[IRL] mintInvites failed: \(error.localizedDescription)")
        }
    }

    private func inviteShareText(codes: [String]) -> String {
        let codeList = codes.joined(separator: ", ")
        return """
        Come join me on IRL — a smaller, safer social network for real friends.

        50 friends max, no ads, end-to-end encrypted. You hold the keys.

        Use one of my invite codes when you sign up: \(codeList)
        """
    }
}

private struct DotsGrid: View {
    let filled: Int
    let total: Int
    let ghost: Int
    let redeemedBonus: Int

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < filled ? IRLColors.oceanBlue : Color.white.opacity(0.12))
                    .frame(width: 14, height: 14)
            }
            ForEach(0..<ghost, id: \.self) { i in
                let unlocked = i < redeemedBonus
                Circle()
                    .fill(unlocked ? IRLColors.earthGreen : Color.clear)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().stroke(IRLColors.earthGreen.opacity(unlocked ? 1 : 0.4), style: StrokeStyle(lineWidth: 1.5, dash: unlocked ? [] : [3]))
                    )
            }
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 5. Permissions

private struct PermissionsStep: View {
    var onDone: () -> Void
    @State private var requestingPush = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 60)

            VStack(spacing: 8) {
                Text("One more thing.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Two permissions, both optional.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer().frame(height: 12)

            VStack(spacing: 10) {
                PermissionCard(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    text: "For comments and reactions from your circle. Nothing else — we promise.",
                    cta: requestingPush ? "Asking…" : "Allow",
                    action: {
                        requestingPush = true
                        Task {
                            await PushService.shared.requestAuthorizationAndRegister()
                            requestingPush = false
                        }
                    }
                )
                PermissionCard(
                    icon: "mappin.circle.fill",
                    title: "Location",
                    text: "Only city-level. Only when you want a pin on the world map.",
                    cta: "Allow",
                    action: { LocationService.shared.requestPermission() }
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            Button { onDone() } label: {
                Text("Get Started")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 36)
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let text: String
    let cta: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(IRLColors.oceanBlue)
                .frame(width: 36, height: 36)
                .background(IRLColors.oceanBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(2)
            }

            Spacer()

            Button(cta, action: action)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
