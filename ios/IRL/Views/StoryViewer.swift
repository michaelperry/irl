import SwiftUI
import UIKit
import AVKit

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
    @State private var videoPlayer: AVPlayer?
    @State private var videoEndObserver: NSObjectProtocol?
    @State private var videoTempURLs: [URL] = []   // cleaned up on dismiss

    private let photoDuration: Double = 5.0
    private let maxVideoDuration: Double = 15.0    // cap for v1

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
        .onDisappear { teardown() }
        .task(id: index) {
            await markCurrentViewed()
            await prepareMediaForCurrent()
        }
    }

    @ViewBuilder
    private var currentBody: some View {
        let s = group.stories[index]
        let plain = decryptedCaption(for: s)

        ZStack {
            if s.isVideo, let player = videoPlayer {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if !s.isVideo, let raw = s.encryptedMediaUrl,
                      let data = Data(base64Encoded: raw),
                      let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            VStack {
                Spacer()
                if let plain, !plain.isEmpty {
                    Text(plain)
                        .font(.system(size: hasMedia(s) ? 18 : 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            hasMedia(s)
                                ? AnyShapeStyle(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.clear)
                        )
                }
                if !hasMedia(s) && (plain == nil || plain?.isEmpty == true) {
                    Text("[unable to decrypt]")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer().frame(height: hasMedia(s) ? 80 : 0)
            }
        }
    }

    private func hasMedia(_ s: Story) -> Bool {
        s.encryptedMediaUrl != nil
    }

    private func decryptedCaption(for s: Story) -> String? {
        guard let cipher = s.encryptedContent else { return nil }
        if let env = s.myEnvelope,
           let key = try? CryptoService.openSealedKey(env),
           let text = try? CryptoService.decryptContent(cipher, under: key) {
            return text
        }
        return cipher
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
                // Videos drive their own progress via the player's currentTime; photos use the timer.
                let s = group.stories[index]
                if s.isVideo {
                    await MainActor.run {
                        if let player = videoPlayer {
                            let cur = CMTimeGetSeconds(player.currentTime())
                            progress = min(1, cur / maxVideoDuration)
                        }
                    }
                } else {
                    await MainActor.run {
                        progress += Double(stepMs) / 1000.0 / photoDuration
                        if progress >= 1 { goNext() }
                    }
                }
            }
        }
    }

    private func prepareMediaForCurrent() async {
        let s = group.stories[index]
        // Tear down previous player
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }
        videoPlayer?.pause()
        videoPlayer = nil

        guard s.isVideo, let raw = s.encryptedMediaUrl, let data = Data(base64Encoded: raw) else {
            return
        }

        // Write to a temp file so AVPlayer can play it
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("story_\(s.id).mov")
        do {
            try data.write(to: tmpURL, options: .atomic)
            videoTempURLs.append(tmpURL)
        } catch {
            print("[IRL] story video write failed: \(error.localizedDescription)")
            return
        }

        let player = AVPlayer(url: tmpURL)
        player.isMuted = false
        await MainActor.run {
            videoPlayer = player
            videoEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                goNext()
            }
            player.play()
        }
    }

    private func teardown() {
        ticker?.cancel()
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        videoPlayer?.pause()
        videoPlayer = nil
        for url in videoTempURLs { try? FileManager.default.removeItem(at: url) }
        videoTempURLs = []
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
