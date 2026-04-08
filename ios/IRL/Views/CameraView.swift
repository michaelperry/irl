import SwiftUI

struct CameraView: View {

    @State private var flashEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                IRLColors.deepSpace
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 200, height: 200)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Text("Camera access required")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Button {
                        // TODO: Capture photo
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 80, height: 80)

                            Circle()
                                .fill(.white)
                                .frame(width: 66, height: 66)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flashEnabled.toggle()
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    CameraView()
}
