import SwiftUI

/// Quick text-only story composer. Camera-based stories will land in a follow-up.
struct StoryComposerSheet: View {
    var onPublished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var sending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                IRLColors.deepSpace.ignoresSafeArea()

                VStack(spacing: 18) {
                    Text("Share a moment.\nGone in 24 hours.")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)

                    TextField("What's happening?", text: $text, axis: .vertical)
                        .font(.system(size: 18, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                        .lineLimit(3...8)
                        .padding(14)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)

                    Spacer()

                    Button {
                        Task { await publish() }
                    } label: {
                        HStack(spacing: 8) {
                            if sending { ProgressView().tint(.black) }
                            Text(sending ? "Posting…" : "Post story")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canPost ? Color.white : Color.white.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .disabled(!canPost || sending)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .alert("Couldn't post", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func publish() async {
        let plaintext = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plaintext.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            // E2E: fetch audience, encrypt with fresh content key, seal for each recipient.
            let audience = (try? await APIClient.shared.getStoryAudience()) ?? []
            let recipientsWithKeys = audience.filter { $0.encryptionPublicKey != nil }

            let payload: String
            var envelopes: [(recipientId: String, sealedKey: String)] = []
            if !recipientsWithKeys.isEmpty {
                let key = CryptoService.freshContentKey()
                payload = try CryptoService.encryptContent(plaintext, under: key)
                for r in recipientsWithKeys {
                    if let pub = r.encryptionPublicKey,
                       let sealed = try? CryptoService.sealContentKey(key, forRecipientPubKeyBase64: pub) {
                        envelopes.append((recipientId: r.id, sealedKey: sealed))
                    }
                }
            } else {
                payload = plaintext  // plaintext fallback
            }

            _ = try await APIClient.shared.createStory(
                encryptedContent: payload,
                envelopes: envelopes
            )
            onPublished()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
