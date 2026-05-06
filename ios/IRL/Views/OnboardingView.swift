import SwiftUI
import UIKit
import UserNotifications
import CoreLocation

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step: Int = 0
    @State private var hasMintedInvites = false
    @State private var sharePayload: String?
    @State private var presentShare = false
    @State private var inviteRedeemedCount: Int = 0

    private let totalSteps = 4

    /// IRL is "earth at night" — onboarding stays dark regardless of any global theme.
    private static let onboardingBackground = Color(red: 0.04, green: 0.05, blue: 0.10)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Self.onboardingBackground.ignoresSafeArea()
                glowLayer
                earthLayer(in: geo)
                contentLayer
                chromeLayer
            }
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $presentShare, onDismiss: { presentShare = false }) {
                if let payload = sharePayload {
                    ShareActivityView(items: [payload])
                }
            }
        }
    }

    // MARK: - Background glow

    private var glowLayer: some View {
        Circle()
            .fill(RadialGradient(
                colors: [IRLColors.oceanBlue.opacity(0.32), .clear],
                center: .center, startRadius: 60, endRadius: 320
            ))
            .frame(width: 520, height: 520)
            .blur(radius: 30)
            .offset(y: step == 0 ? 0 : -180)
            .opacity(step == 0 ? 1 : 0.35)
            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: step)
            .ignoresSafeArea()
    }

    // MARK: - Persistent earth

    private func earthLayer(in geo: GeometryProxy) -> some View {
        let size: CGFloat = step == 0 ? 240 : 130
        let yOffset: CGFloat = step == 0 ? -geo.size.height * 0.10 : -geo.size.height * 0.32

        return EarthView(autoRotate: true)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(IRLColors.earthGradient.opacity(0.25), lineWidth: 1.5))
            .shadow(color: IRLColors.oceanBlue.opacity(0.3), radius: step == 0 ? 50 : 28)
            .offset(y: yOffset)
            .opacity(step == 0 ? 1.0 : 0.9)
            .animation(.spring(response: 0.65, dampingFraction: 0.85), value: step)
    }

    // MARK: - Step content

    private var contentLayer: some View {
        Group {
            switch step {
            case 0: heroContent
            case 1: pillarsContent
            case 2: inviteContent
            case 3: permissionsContent
            default: EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 12)),
            removal: .opacity.combined(with: .offset(y: -12))
        ))
        .id(step)
    }

    // MARK: - Chrome (step dots + primary button)

    private var chromeLayer: some View {
        VStack {
            StepDots(current: step, total: totalSteps)
                .padding(.top, 20)
            Spacer()
            primaryButton
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case 0, 1:
            ContinueButton(label: "Continue", action: advance)
        case 2:
            VStack(spacing: 10) {
                ContinueButton(label: hasMintedInvites ? "Continue" : "Send Invites") {
                    if hasMintedInvites {
                        advance()
                    } else {
                        Task { await mintAndShare() }
                    }
                }
                if !hasMintedInvites {
                    Button("Skip for now", action: advance)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        case 3:
            ContinueButton(label: "Get Started", action: complete)
        default:
            EmptyView()
        }
    }

    // MARK: - Step views

    private var heroContent: some View {
        VStack(spacing: 12) {
            Spacer()
            Spacer().frame(height: 100)
            Text("A smaller internet.")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Made for the 50 people\nwho actually matter.")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
            Spacer().frame(height: 110) // leave room for chrome
        }
        .padding(.horizontal, 24)
    }

    private var pillarsContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text("Our promise.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Four things we'll never compromise on.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                PillarCard(emoji: "🌍", title: "Real-life sized",
                           text: "Capped at 50 friends. That's how many faces you actually know.")
                PillarCard(emoji: "🛡", title: "No manipulation",
                           text: "Chronological. No ads. No tracking. No algorithm picking what you see.")
                PillarCard(emoji: "🔑", title: "Your data, your keys",
                           text: "End-to-end encrypted. Your keys live on this device — we literally can't read your stuff.")
                PillarCard(emoji: "✅", title: "Verified real",
                           text: "No bots. No AI-generated content. We mark what's truly captured live.")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Spacer()
            Spacer().frame(height: 100)
        }
    }

    private var inviteContent: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 30)
            VStack(spacing: 8) {
                Text("Invite 5. Unlock 5.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Bring 5 real-life friends. We'll unlock\n5 more spots in your circle.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)

            BonusSlotRow(redeemed: inviteRedeemedCount, total: 5)
                .padding(.top, 8)

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Your circle: 0 of 50  ·  +5 bonus available")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()
            Spacer().frame(height: 100)
        }
    }

    private var permissionsContent: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 30)
            VStack(spacing: 6) {
                Text("One more thing.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Both optional. Both stay off until you turn them on.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(spacing: 10) {
                NotificationsPermissionCard()
                LocationPermissionCard()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer()
            Spacer().frame(height: 100)
        }
    }

    // MARK: - Actions

    private func advance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "irl_onboarding_completed")
        onComplete()
    }

    private func mintAndShare() async {
        do {
            let minted = try await APIClient.shared.mintInvites(count: 5)
            inviteRedeemedCount = minted.filter { $0.isRedeemed }.count
            let codes = minted.filter { !$0.isRedeemed }.prefix(5).map { $0.code }
            sharePayload = inviteShareText(codes: Array(codes))
            hasMintedInvites = true
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

// MARK: - Buttons

private struct ContinueButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Pillar card

private struct PillarCard: View {
    let emoji: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 22))
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Bonus slot row (compact)

private struct BonusSlotRow: View {
    let redeemed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<total, id: \.self) { i in
                let unlocked = i < redeemed
                ZStack {
                    Circle()
                        .fill(unlocked ? IRLColors.earthGreen.opacity(0.22) : Color.clear)
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(
                            unlocked ? IRLColors.earthGreen : Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.6, dash: unlocked ? [] : [3])
                        )
                        .frame(width: 36, height: 36)
                    if unlocked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(IRLColors.earthGreen)
                    } else {
                        Text("+1")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }
}

// MARK: - Permission cards (with post-grant "Allowed" state)

private struct NotificationsPermissionCard: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var working = false

    var body: some View {
        PermissionCard(
            icon: "bell.badge.fill",
            title: "Notifications",
            text: "For comments and reactions from your circle. Nothing else — we promise.",
            granted: status == .authorized || status == .provisional || status == .ephemeral,
            denied: status == .denied,
            working: working,
            onAllow: { Task { await request() } }
        )
        .task { await refreshStatus() }
    }

    private func refreshStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { status = s.authorizationStatus }
    }

    private func request() async {
        working = true
        defer { working = false }
        await PushService.shared.requestAuthorizationAndRegister()
        await refreshStatus()
    }
}

private struct LocationPermissionCard: View {
    @State private var status: CLAuthorizationStatus = .notDetermined

    var body: some View {
        PermissionCard(
            icon: "mappin.circle.fill",
            title: "Location",
            text: "Only city-level. Only when you want a pin on the world map.",
            granted: status == .authorizedWhenInUse || status == .authorizedAlways,
            denied: status == .denied || status == .restricted,
            working: false,
            onAllow: {
                LocationService.shared.requestPermission()
                // Re-poll shortly — iOS doesn't push us a status change synchronously
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await refreshStatus()
                }
            }
        )
        .task { await refreshStatus() }
    }

    private func refreshStatus() async {
        let s = CLLocationManager().authorizationStatus
        await MainActor.run { status = s }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let text: String
    let granted: Bool
    let denied: Bool
    let working: Bool
    let onAllow: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(granted ? IRLColors.earthGreen : IRLColors.oceanBlue)
                .frame(width: 36, height: 36)
                .background((granted ? IRLColors.earthGreen : IRLColors.oceanBlue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            statePill
        }
        .padding(12)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var statePill: some View {
        if granted {
            HStack(spacing: 4) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                Text("Allowed").font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(IRLColors.earthGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(IRLColors.earthGreen.opacity(0.14))
            .clipShape(Capsule())
        } else if denied {
            Text("In Settings")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.06))
                .clipShape(Capsule())
        } else {
            Button(action: onAllow) {
                HStack(spacing: 4) {
                    if working { ProgressView().tint(.black).scaleEffect(0.7) }
                    Text(working ? "Asking…" : "Allow")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white)
                .clipShape(Capsule())
            }
            .disabled(working)
        }
    }
}

// MARK: - Share sheet wrapper

private struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
