import SwiftUI

struct ActivitySheet: View {
    var onDismiss: () -> Void

    @State private var activities: [Activity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasMore = false
    @State private var cursor: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && activities.isEmpty {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if activities.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(activities) { row(for: $0) }
                            if hasMore {
                                Button { Task { await loadMore() } } label: {
                                    Text("Load more")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(IRLColors.oceanBlue)
                                        .padding(.vertical, 14)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onDismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .task { await load() }
            .alert("Couldn't load activity", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 36))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.4))
            Text("Nothing new")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("Reactions, comments, and new friends will land here.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(for a: Activity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.iconName)
                .font(.system(size: 16))
                .foregroundStyle(IRLColors.oceanBlue)
                .frame(width: 36, height: 36)
                .background(IRLColors.oceanBlue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(a.headline)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                Text(a.createdAt)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            if !a.isRead {
                Circle().fill(IRLColors.oceanBlue).frame(width: 7, height: 7)
            }
        }
        .padding(12)
        .background(.white.opacity(a.isRead ? 0.02 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.getActivity()
            activities = r.activities
            hasMore = r.hasMore
            cursor = r.nextCursor
            // Mark read on view (fire-and-forget)
            Task { try? await APIClient.shared.markActivityRead() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let cursor else { return }
        do {
            let r = try await APIClient.shared.getActivity(before: cursor)
            activities.append(contentsOf: r.activities)
            hasMore = r.hasMore
            self.cursor = r.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
