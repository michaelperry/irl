import SwiftUI

/// Full-screen tap-through viewer for a single author's stories.
struct StoryViewer: View {
    let group: StoryGroup
    var onClose: () -> Void
    var onAdvanceGroup: () -> Void          // moves to the next group when this group ends
    var onPreviousGroup: () -> Void         // moves to the previous group when at first story

    @State private var index: Int = 0
    @State private var progress: Double = 0
    @State private var ticker: Task<Void, Never>?
    @State private var paused: Bool = false

    private let perStorySeconds: Double = 5.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Decrypted content if we have it; placeholder otherwise.
            currentBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tap zones: left = back, right = forward
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goBack() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goNext() }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.18)
                    .onChanged { _ in paused = true }
                    .onEnded { _ in paused = false }
            )

            VStack {
                // Progress bar segments
                HStack(spacing: 4) {
                    ForEach(group.stories.indices, id: \.self) { i in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.25))
                                Capsule()
                                    .fill(.white)
                                    .frame(width: geo.size.width * fillFor(i))
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                HStack(spacing: 10) {
                    EarthView(autoRotate: false)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(IRLColors.earthGradient, lineWidth: 1.4))
                    Text(group.authorName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 { onClose() }
                }
        )
        .task { startTicker() }
        .onDisappear { ticker?.cancel() }
        .task(id: index) { await markCurrentViewed() }
    }

    @ViewBuilder
    private var currentBody: some View {
        let s = group.stories[index]
        // Decrypt envelope-protected text content if present
        let plain: String? = {
            guard let env = s.myEnvelope, let cipher = s.encryptedContent else { return s.encryptedContent }
            if let key = try? CryptoService.openSealedKey(env),
               let text = try? CryptoService.decryptContent(cipher, under: key) {
                return text
            }
            return nil
        }()

        VStack(spacing: 16) {
            Spacer()
            if let plain {
                Text(plain)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else if s.encryptedMediaUrl != nil {
                Image(systemName: "photo")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Media stories soon")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("[unable to decrypt]")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private func fillFor(_ i: Int) -> Double {
        if i < index { return 1 }
        if i > index { return 0 }
        return progress
    }

    private func startTicker() {
        ticker?.cancel()
        progress = 0
        ticker = Task {
            let stepMs: UInt64 = 50
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: stepMs * 1_000_000)
                if Task.isCancelled { return }
                if paused { continue }
                await MainActor.run {
                    progress += Double(stepMs) / 1000.0 / perStorySeconds
                    if progress >= 1 {
                        goNext()
                    }
                }
            }
        }
    }

    private func goNext() {
        if index + 1 < group.stories.count {
            index += 1
            progress = 0
        } else {
            onAdvanceGroup()
        }
    }

    private func goBack() {
        if index > 0 {
            index -= 1
            progress = 0
        } else {
            onPreviousGroup()
        }
    }

    private func markCurrentViewed() async {
        let s = group.stories[index]
        try? await APIClient.shared.markStoryViewed(s.id)
    }
}
