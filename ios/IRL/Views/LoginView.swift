import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ZStack {
            IRLColors.earthGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)

                Text("irl")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                Text("the people's app")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 8)

                Spacer()

                Button {
                    Task { await authService.authenticate() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 22))
                        Text("Sign in with Face ID")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(IRLColors.oceanBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 32)

                if let error = authService.authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 12)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
