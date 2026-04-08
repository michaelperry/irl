import SwiftUI

struct FeedView: View {

    private let posts = Post.samples

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(posts) { post in
                        PostCard(post: post)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Post Model

private struct Post: Identifiable {
    let id = UUID()
    let author: String
    let timeAgo: String
    let encryptedPreview: String
    let friendCount: Int

    static let samples: [Post] = [
        Post(author: "Maya", timeAgo: "2m ago", encryptedPreview: "Just got back from the ocean...", friendCount: 4),
        Post(author: "Jordan", timeAgo: "18m ago", encryptedPreview: "Morning hike with the crew", friendCount: 7),
        Post(author: "Sage", timeAgo: "1h ago", encryptedPreview: "Making dinner for everyone tonight", friendCount: 3),
        Post(author: "River", timeAgo: "3h ago", encryptedPreview: "Found the best spot in the park", friendCount: 12),
        Post(author: "Kai", timeAgo: "5h ago", encryptedPreview: "Sunset session was unreal", friendCount: 6),
    ]
}

// MARK: - Post Card

private struct PostCard: View {

    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(IRLColors.earthGradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(post.author.prefix(1)))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Text(post.timeAgo)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("E2E")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(IRLColors.earthGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(IRLColors.earthGreen.opacity(0.12))
                .clipShape(Capsule())
            }

            // Placeholder image area
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(height: 200)
                .overlay {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                }

            Text(post.encryptedPreview)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                Text("Seen by \(post.friendCount) friends")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

#Preview {
    FeedView()
}
