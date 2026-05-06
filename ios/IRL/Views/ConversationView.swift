import SwiftUI

struct ConversationView: View {
    let otherId: String
    let otherName: String
    let otherPubKey: String?

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    @State private var conversationId: String?
    @State private var draft: String = ""
    @State private var sending = false
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var lastMessageId: String?

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            composer
        }
        .background(IRLColors.deepSpace.ignoresSafeArea())
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
        .task {
            await loadInitial()
            startPolling()
        }
        .onDisappear { pollTask?.cancel() }
        .alert("Couldn't send", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(messages) { m in
                        bubble(for: m).id(m.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .onChange(of: lastMessageId) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(for m: Message) -> some View {
        let mine = m.senderId != otherId
        HStack {
            if mine { Spacer(minLength: 60) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                Text(m.decryptedText ?? "[encrypted]")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(mine ? .white : IRLColors.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(mine ? IRLColors.oceanBlue : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !mine { Spacer(minLength: 60) }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(IRLColors.primaryText)

            Button { Task { await send() } } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? IRLColors.oceanBlue : Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .disabled(!canSend || sending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadInitial() async {
        loading = true
        defer { loading = false }
        do {
            let r = try await APIClient.shared.getConversation(withUserId: otherId)
            conversationId = r.conversation.id
            messages = decryptAll(r.messages)
            lastMessageId = messages.last?.id
            await markRead()
        } catch let APIError.serverError(code, msg) where code == 403 {
            errorMessage = msg.contains("not_mutual_friends")
                ? "You can only DM mutual friends."
                : msg
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decryptAll(_ raw: [Message]) -> [Message] {
        raw.map { m in
            var c = m
            if let env = m.myEnvelope,
               let key = try? CryptoService.openSealedKey(env),
               let plain = try? CryptoService.decryptContent(m.ciphertext, under: key) {
                c.decryptedText = plain
            } else {
                c.decryptedText = "[unable to decrypt]"
            }
            return c
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                await refreshLatest()
            }
        }
    }

    private func refreshLatest() async {
        do {
            let r = try await APIClient.shared.getConversation(withUserId: otherId)
            let fresh = decryptAll(r.messages)
            await MainActor.run {
                if fresh.last?.id != messages.last?.id || fresh.count != messages.count {
                    messages = fresh
                    lastMessageId = fresh.last?.id
                    Task { await markRead() }
                }
            }
        } catch {
            // Silent during background polling
        }
    }

    private func markRead() async {
        guard let conversationId else { return }
        try? await APIClient.shared.markConversationRead(conversationId: conversationId)
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }

        // Build envelopes for self + recipient
        let myPub = try? CryptoService.currentPublicKeyBase64()
        let recipientPub = otherPubKey
        let myUserId = KeychainService.userId

        let payload: String
        var envelopes: [(recipientId: String, sealedKey: String)] = []

        if let recipientPub, let myPub, let myUserId, myPub.isEmpty == false {
            let key = CryptoService.freshContentKey()
            do {
                payload = try CryptoService.encryptContent(text, under: key)
                if let sealedForOther = try? CryptoService.sealContentKey(key, forRecipientPubKeyBase64: recipientPub) {
                    envelopes.append((recipientId: otherId, sealedKey: sealedForOther))
                }
                if let sealedForSelf = try? CryptoService.sealContentKey(key, forRecipientPubKeyBase64: myPub) {
                    envelopes.append((recipientId: myUserId, sealedKey: sealedForSelf))
                }
            } catch {
                payload = text
            }
        } else {
            payload = text  // plaintext fallback if either side missing pubkey
        }

        do {
            var sent = try await APIClient.shared.sendMessage(toUserId: otherId, ciphertext: payload, envelopes: envelopes)
            sent.decryptedText = text
            messages.append(sent)
            lastMessageId = sent.id
            draft = ""
        } catch let APIError.serverError(code, msg) where code == 403 {
            errorMessage = msg.contains("not_mutual_friends")
                ? "You can only DM mutual friends."
                : msg
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
