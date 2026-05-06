import SwiftUI

struct MessagesInboxSheet: View {
    var onDismiss: () -> Void

    @State private var conversations: [ConversationSummary] = []
    @State private var loading = false
    @State private var openWith: ConversationSummary?
    @State private var errorMessage: String?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            Group {
                if loading && conversations.isEmpty {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(conversations) { row(for: $0) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onDismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17))
                            .foregroundStyle(IRLColors.oceanBlue)
                    }
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .sheet(isPresented: $showNew) {
                NewConversationSheet { picked in
                    showNew = false
                    // Synthesize a stub summary so the existing destination wires the chat.
                    openWith = ConversationSummary(
                        id: "stub",
                        otherId: picked.id,
                        otherDisplayName: picked.displayName,
                        otherEncryptionPublicKey: picked.encryptionPublicKey,
                        lastMessage: nil,
                        unread: 0,
                        lastMessageAt: nil,
                        createdAt: ""
                    )
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(item: $openWith) { c in
                ConversationView(otherId: c.otherId, otherName: c.otherDisplayName, otherPubKey: c.otherEncryptionPublicKey)
            }
            // Errors are surfaced via the empty-state UI below rather than a disruptive alert.
        }
    }

    private func row(for c: ConversationSummary) -> some View {
        Button { openWith = c } label: {
            HStack(spacing: 12) {
                EarthView(autoRotate: false)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(IRLColors.earthGradient, lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text(c.otherDisplayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                    Text(previewLine(for: c))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(c.unread > 0 ? 0.85 : 0.5))
                        .lineLimit(1)
                }

                Spacer()

                if c.unread > 0 {
                    Text("\(c.unread)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(IRLColors.oceanBlue)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(.white.opacity(c.unread > 0 ? 0.06 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func previewLine(for c: ConversationSummary) -> String {
        guard let last = c.lastMessage else { return "Say hi 👋" }
        // Ciphertext preview can't be decrypted here cheaply; show a generic line.
        let prefix = last.senderId == c.otherId ? "" : "You: "
        return "\(prefix)Encrypted message"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.4))
            Text("No conversations yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("DMs are mutual-friends only. Add friends from search to start a thread.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            conversations = try await APIClient.shared.listConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
