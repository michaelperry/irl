import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var authService: AuthService

    @State private var glowPhase: Double = 0
    @State private var entered = false
    @State private var manifestoIndex = 0

    private let manifesto = [
        "own your data",
        "fully encrypted",
        "no brands",
        "no duplicates, everyone's verified",
        "customize your feed",
        "connectivity without manipulation",
    ]

    var body: some View {
        GeometryReader { geo in
            let earthSize = geo.size.width * 0.85

            ZStack {
                Color.black.ignoresSafeArea()

                // Twinkling stars
                TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        for i in 0..<100 {
                            let x = CGFloat((i * 7919 + i * 13) % Int(size.width))
                            let y = CGFloat((i * 6271 + i * 7) % Int(size.height))
                            let twinkle = sin(time * Double(i % 5 + 1) * 0.5 + Double(i)) * 0.3 + 0.4
                            let s = CGFloat((i * 2953) % 3) / 2.5 + 0.3
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                                with: .color(.white.opacity(twinkle * 0.5))
                            )
                        }
                    }
                }
                .ignoresSafeArea()

                // Atmospheric glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                IRLColors.oceanBlue.opacity(0.2 + glowPhase * 0.1),
                                IRLColors.earthGreen.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: earthSize * 0.3,
                            endRadius: earthSize * 0.9
                        )
                    )
                    .frame(width: earthSize * 1.6, height: earthSize * 1.6)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.30)
                    .blur(radius: 40)

                VStack(spacing: 0) {

                    Spacer()
                        .frame(height: geo.size.height * 0.06)

                    // Dynamic 3D Earth — shows correct face & day/night for your location
                    EarthView()
                        .frame(width: earthSize, height: earthSize)
                        .shadow(color: IRLColors.oceanBlue.opacity(0.3), radius: 50)
                        .scaleEffect(entered ? 1.0 : 0.9)
                        .opacity(entered ? 1.0 : 0)

                    Spacer()

                    // Bold identity
                    Text("irl")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(6)
                        .frame(maxWidth: .infinity)
                        .opacity(entered ? 1.0 : 0)

                    // Rotating manifesto tagline
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
                        .opacity(entered ? 1.0 : 0)

                    // Value pills
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
                    .padding(.top, 28)
                    .frame(maxWidth: .infinity)
                    .opacity(entered ? 1.0 : 0)

                    Spacer()

                    // CTA
                    Button {
                        Task { await authService.authenticate() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.system(size: 22, weight: .medium))
                            Text("Sign in with Face ID")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 36)
                    .opacity(entered ? 1.0 : 0)

                    if let error = authService.authError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 44)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                entered = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
            // Rotate taglines
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
