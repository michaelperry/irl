import SwiftUI

struct CommentsSheet: View {
    let postServerId: String?
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var draft: String = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var replyTarget: Comment?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && comments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(topLevel) { c in
                                commentRow(c, isReply: false)
                                ForEach(replies(of: c.id)) { r in
                                    commentRow(r, isReply: true)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                    }
                }

                composer
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .task { await load() }
            .alert("Couldn't load comments", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var topLevel: [Comment] {
        comments.filter { $0.parentCommentId == nil }
    }

    private func replies(of id: String) -> [Comment] {
        comments.filter { $0.parentCommentId == id }
    }

    private func commentRow(_ c: Comment, isReply: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(IRLColors.oceanBlue.opacity(0.3))
                .frame(width: isReply ? 24 : 30, height: isReply ? 24 : 30)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.7)).font(.system(size: isReply ? 12 : 14)))

            VStack(alignment: .leading, spacing: 4) {
                Text(c.decryptedContent ?? c.encryptedContent)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)

                HStack(spacing: 12) {
                    Text(c.createdAt)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    if !isReply {
                        Button("Reply") { replyTarget = c }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(IRLColors.oceanBlue)
                    }
                }
            }
            Spacer()
        }
        .padding(.leading, isReply ? 36 : 0)
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let target = replyTarget {
                HStack {
                    Text("Replying to a comment").font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Button { replyTarget = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    let _ = target.id // keep target referenced
                }
                .padding(.horizontal, 12)
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(IRLColors.primaryText)

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(canSend ? IRLColors.oceanBlue : Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .disabled(!canSend || isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.5))
            Text("No comments yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("Be the first to chime in.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && postServerId != nil
    }

    private func load() async {
        guard let postServerId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await APIClient.shared.getComments(postId: postServerId)
            // Decrypt comments that have an envelope addressed to us; otherwise treat as plaintext.
            let decrypted: [Comment] = fetched.map { c in
                var copy = c
                if let envelope = c.myEnvelope {
                    if let key = try? CryptoService.openSealedKey(envelope),
                       let plain = try? CryptoService.decryptContent(c.encryptedContent, under: key) {
                        copy.decryptedContent = plain
                    } else {
                        copy.decryptedContent = "[unable to decrypt]"
                    }
                } else {
                    copy.decryptedContent = c.encryptedContent  // plaintext fallback
                }
                return copy
            }
            self.comments = decrypted
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let postServerId else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            // Try E2E: fetch audience pubkeys, seal a fresh content key for each, encrypt content under it.
            let audience = (try? await APIClient.shared.getPostAudience(postId: postServerId)) ?? []
            let recipientsWithKeys = audience.filter { $0.encryptionPublicKey != nil }

            let payload: String
            var envelopes: [(recipientId: String, sealedKey: String)] = []

            if !recipientsWithKeys.isEmpty {
                let contentKey = CryptoService.freshContentKey()
                payload = try CryptoService.encryptContent(text, under: contentKey)
                for r in recipientsWithKeys {
                    if let pub = r.encryptionPublicKey,
                       let sealed = try? CryptoService.sealContentKey(contentKey, forRecipientPubKeyBase64: pub) {
                        envelopes.append((recipientId: r.id, sealedKey: sealed))
                    }
                }
            } else {
                // Audience has no encryption keys yet — fall back to plaintext.
                payload = text
            }

            let created = try await APIClient.shared.createComment(
                postId: postServerId,
                encryptedContent: payload,
                parentCommentId: replyTarget?.id,
                envelopes: envelopes
            )
            var withDecrypted = created
            withDecrypted.decryptedContent = text
            comments.append(withDecrypted)
            draft = ""
            replyTarget = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
