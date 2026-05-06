import SwiftUI
import SceneKit

struct LoginView: View {

    @EnvironmentObject private var authService: AuthService

    @State private var zoomPhase: CGFloat = 0 // 0 = zoomed in on surface, 1 = full Earth, 2 = deep space
    @State private var showUI = false
    @State private var glowPhase: Double = 0
    @State private var manifestoIndex = 0
    @State private var showInviteCodeEntry = false
    @State private var pendingInviteCode: String?

    private let manifesto = [
        "a smaller, safer, internet",
        "every post made by a real human",
        "no ai. no bots. no fakes.",
        "own your data",
        "fully encrypted",
        "no brands",
        "no duplicates, everyone's verified",
        "customize your feed",
        "connectivity without manipulation",
    ]

    // Zoom duration in seconds
    private let zoomDuration: Double = 5.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Star field — fades in as we zoom out
                TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        for i in 0..<150 {
                            let x = CGFloat((i * 7919 + i * 13) % Int(size.width))
                            let y = CGFloat((i * 6271 + i * 7) % Int(size.height))
                            let twinkle = sin(time * Double(i % 5 + 1) * 0.5 + Double(i)) * 0.3 + 0.4
                            let s = CGFloat((i * 2953) % 3) / 2.5 + 0.3
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                                with: .color(.white.opacity(twinkle * starOpacity))
                            )
                        }
                    }
                }
                .ignoresSafeArea()

                // Atmospheric glow — appears during mid-zoom
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                IRLColors.oceanBlue.opacity(0.2 + glowPhase * 0.1),
                                IRLColors.earthGreen.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 100,
                            endRadius: 300
                        )
                    )
                    .frame(width: 500, height: 500)
                    .position(x: geo.size.width / 2, y: earthCenterY(geo))
                    .blur(radius: 40)
                    .opacity(atmosphereOpacity)

                // 3D Earth — zooms from huge (surface-level) to normal size
                EarthView(autoRotate: true)
                    .frame(width: earthSize(geo), height: earthSize(geo))
                    .position(x: geo.size.width / 2, y: earthCenterY(geo))
                    .shadow(color: IRLColors.oceanBlue.opacity(0.3 * earthGlowOpacity), radius: 50)

                // "you are here" — fades as we zoom out
                Text("we are here.")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)
                    .position(x: geo.size.width / 2, y: earthCenterY(geo) + earthSize(geo) * 0.08)
                    .opacity(max(0, 1 - zoomPhase * 3))

                // UI content — fades in after zoom completes
                signInPanel
                    .frame(maxWidth: .infinity)
                    .opacity(showUI ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startZoomSequence()
        }
        .sheet(isPresented: $showInviteCodeEntry) {
            InviteCodeEntryView(initial: pendingInviteCode ?? "") { code in
                pendingInviteCode = code.isEmpty ? nil : code
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var signInPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("irl")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(6)
                .frame(maxWidth: .infinity)

            Text(manifesto[manifestoIndex])
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .padding(.top, 8)
                .id(manifestoIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))

            valuePillsBlock
                .padding(.top, 28)
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 32)

            signInButton
                .padding(.horizontal, 36)

            inviteCodeButton
                .padding(.top, 12)

            if let error = authService.authError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 12)
            }

            if authService.isLoading {
                ProgressView().tint(.white).padding(.top, 12)
            }

            Spacer().frame(height: 44)
        }
    }

    private var valuePillsBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ValuePill(icon: "lock.fill", text: "Encrypted")
                ValuePill(icon: "hand.raised.fill", text: "Own Your Data")
                ValuePill(icon: "checkmark.seal.fill", text: "Verified")
            }
            HStack(spacing: 16) {
                ValuePill(icon: "slider.horizontal.3", text: "Your Feed")
                ValuePill(icon: "nosign", text: "No Brands")
                ValuePill(icon: "eye.slash.fill", text: "No Ads")
            }
            HStack(spacing: 16) {
                ValuePill(icon: "heart.fill", text: "Always Be Kind")
            }
        }
    }

    private var signInButton: some View {
        Button {
            Task { await authService.authenticate(inviteCode: pendingInviteCode) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "faceid").font(.system(size: 22, weight: .medium))
                Text("Sign in with Face ID")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(.white)
            .clipShape(Capsule())
        }
    }

    private var inviteCodeButton: some View {
        let hasCode = pendingInviteCode != nil
        let label: String = {
            if let code = pendingInviteCode { return "Invite code: \(code)" }
            return "Have an invite code?"
        }()
        let icon = hasCode ? "checkmark.circle.fill" : "ticket"

        return Button {
            showInviteCodeEntry = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(hasCode ? 0.85 : 0.45))
        }
    }

    // MARK: - Zoom calculations

    /// Earth starts at 3x screen width, ends at 70%
    private func earthSize(_ geo: GeometryProxy) -> CGFloat {
        let startSize = geo.size.width * 3.0
        let endSize = geo.size.width * 0.70
        let progress = min(zoomPhase, 1.0)
        let eased = 1 - pow(1 - progress, 2.5) // smooth ease-out
        return startSize + (endSize - startSize) * eased
    }

    /// Earth starts centered, drifts up smoothly
    private func earthCenterY(_ geo: GeometryProxy) -> CGFloat {
        let startY = geo.size.height * 0.42
        let endY = geo.size.height * 0.26
        let progress = min(zoomPhase, 1.0)
        let eased = 1 - pow(1 - progress, 2.5)
        return startY + (endY - startY) * eased
    }

    /// Stars fade in early
    private var starOpacity: Double {
        let progress = min(zoomPhase, 1.0)
        if progress < 0.15 { return 0 }
        return min(Double((progress - 0.15) / 0.35), 1.0) * 0.5
    }

    /// Atmosphere glow fades in sooner
    private var atmosphereOpacity: Double {
        let progress = min(zoomPhase, 1.0)
        if progress < 0.2 { return 0 }
        return min(Double((progress - 0.2) / 0.3), 1.0)
    }

    /// Earth glow intensity
    private var earthGlowOpacity: Double {
        min(Double(zoomPhase), 1.0)
    }

    // MARK: - Animation sequence

    private func startZoomSequence() {
        // Smooth zoom out
        withAnimation(.easeInOut(duration: zoomDuration)) {
            zoomPhase = 1.0
        }

        // Show UI at 50% of zoom — feels integrated, not delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + zoomDuration * 0.45) {
            withAnimation(.easeOut(duration: 1.2)) {
                showUI = true
            }
        }

        // Breathing glow starts as zoom finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + zoomDuration * 0.8) {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        }

        // Taglines start shortly after UI appears
        DispatchQueue.main.asyncAfter(deadline: .now() + zoomDuration * 0.7) {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    manifestoIndex = (manifestoIndex + 1) % manifesto.count
                }
            }
        }
    }
}

struct ValuePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
