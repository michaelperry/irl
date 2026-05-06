import SwiftUI

struct BlockedUsersView: View {
    @State private var blocks: [APIClient.BlockEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && blocks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blocks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(blocks, id: \.blockedId) { entry in
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.blockedId.prefix(8) + "…")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                Text("Blocked \(entry.createdAt)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Unblock") {
                                Task { await unblock(entry.blockedId) }
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(IRLColors.oceanBlue)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(IRLColors.deepSpace.ignoresSafeArea())
        .navigationTitle("Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 36))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.5))
            Text("No one is blocked")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("People you block will appear here.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.blocks = try await APIClient.shared.listBlocks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(_ userId: String) async {
        do {
            try await APIClient.shared.unblockUser(userId)
            blocks.removeAll { $0.blockedId == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
