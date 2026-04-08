import SwiftUI
import UIKit
import AVKit

// MARK: - Feed Filter

enum FeedFilter: String, CaseIterable {
    case friends = "friends"
    case interests = "interests"
    case both = "both"

    var label: String {
        switch self {
        case .friends: return "Friends"
        case .interests: return "Interests"
        case .both: return "Both"
        }
    }

    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .interests: return "sparkles"
        case .both: return "globe.americas.fill"
        }
    }

    var emptyTitle: String {
        switch self {
        case .friends: return "No moments from friends yet."
        case .interests: return "No interest posts yet."
        case .both: return "No moments yet."
        }
    }

    var emptySubtitle: String {
        switch self {
        case .friends: return "Add friends to see their posts here."
        case .interests: return "As you use IRL, we'll surface content that matches your interests — no manipulation, just relevance."
        case .both: return "Be the first to share."
        }
    }

    var emptyIcon: String {
        switch self {
        case .friends: return "person.2"
        case .interests: return "sparkles"
        case .both: return "camera.fill"
        }
    }

    var transparencyDescription: String {
        switch self {
        case .friends: return "Only people you've added. Nothing else."
        case .interests: return "Content matching your interests from verified users. No manipulation."
        case .both: return "Friends first, then interest matches. Fully transparent."
        }
    }
}

// MARK: - Search Category

enum SearchCategory: String, CaseIterable {
    case friends
    case interests
    case location

    var label: String {
        switch self {
        case .friends: return "People"
        case .interests: return "Interests"
        case .location: return "Nearby"
        }
    }

    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .interests: return "sparkles"
        case .location: return "mappin.and.ellipse"
        }
    }

    var searchTitle: String {
        switch self {
        case .friends: return "Find people"
        case .interests: return "Explore interests"
        case .location: return "Discover nearby"
        }
    }

    var searchSubtitle: String {
        switch self {
        case .friends: return "Search by name or username to find and add friends."
        case .interests: return "Find people and content around topics you care about."
        case .location: return "See what's happening around you and across the world."
        }
    }
}

// MARK: - Feed Sort

enum FeedSort: String, CaseIterable {
    case chronological
    case relevance

    var label: String {
        switch self {
        case .chronological: return "Latest first"
        case .relevance: return "Most relevant"
        }
    }

    var icon: String {
        switch self {
        case .chronological: return "clock"
        case .relevance: return "sparkles"
        }
    }
}

// MARK: - Feed View

struct FeedView: View {

    @EnvironmentObject var postStore: PostStore
    @State private var searchText = ""
    @State private var feedFilter: FeedFilter = .friends

    private var allPostLocations: [PostLocation] {
        postStore.posts.compactMap { $0.location }
    }
    @State private var showFeedSettings = false
    @State private var sortOrder: FeedSort = .chronological
    @State private var showWhySheet = false
    @State private var selectedWhyPost: Post?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if !searchText.isEmpty {
                    searchPlaceholder
                } else if filteredPosts.isEmpty {
                    emptyStateForFilter
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPosts) { post in
                            FeedPostCard(post: post, postStore: postStore, onWhyTapped: {
                                selectedWhyPost = post
                                showWhySheet = true
                            })
                        }
                    }
                }
            }
            .refreshable {
                try? await Task.sleep(for: .milliseconds(400))
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search people, interests, or places...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image("EarthBluMarble")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                        Text("irl")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(IRLColors.primaryText)
                            .tracking(2)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Filter section
                        Section("Show me") {
                            ForEach(FeedFilter.allCases, id: \.self) { filter in
                                Button {
                                    feedFilter = filter
                                } label: {
                                    Label(filter.label, systemImage: filter.icon)
                                    if feedFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        // Sort section
                        Section("Sort by") {
                            ForEach(FeedSort.allCases, id: \.self) { sort in
                                Button {
                                    sortOrder = sort
                                } label: {
                                    Label(sort.label, systemImage: sort.icon)
                                    if sortOrder == sort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        // Transparency
                        Button {
                            showFeedSettings = true
                        } label: {
                            Label("Feed Transparency", systemImage: "eye")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: feedFilter.icon)
                                .font(.system(size: 13))
                            Text(feedFilter.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(IRLColors.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showFeedSettings) {
                FeedTransparencyView(feedFilter: $feedFilter, sortOrder: $sortOrder)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWhySheet) {
                if let post = selectedWhyPost {
                    WhyThisPostView(post: post, feedFilter: feedFilter)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        // theme controlled globally from IRLApp
    }

    // MARK: - Filter

    private var filteredPosts: [Post] {
        switch feedFilter {
        case .friends:
            return postStore.posts.filter { $0.authorId == "me" || $0.authorId == "friend" }
        case .interests:
            return postStore.posts.filter { $0.authorId != "me" && $0.authorId != "friend" }
        case .both:
            return postStore.posts
        }
    }

    private var feedFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        feedFilter = filter
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 12))
                            Text(filter.label)
                                .font(.system(size: 13, weight: feedFilter == filter ? .bold : .medium, design: .rounded))
                        }
                        .foregroundStyle(feedFilter == filter ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(feedFilter == filter ? IRLColors.oceanBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .background(IRLColors.deepSpace)
    }

    private var emptyStateForFilter: some View {
        VStack(spacing: 16) {
            Image(systemName: feedFilter.emptyIcon)
                .font(.system(size: 48))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.5))
            Text(feedFilter.emptyTitle)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text(feedFilter.emptySubtitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, 32)
    }

    @State private var searchCategory: SearchCategory = .friends

    private var searchPlaceholder: some View {
        VStack(spacing: 20) {
            // Search category tabs
            HStack(spacing: 0) {
                ForEach(SearchCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchCategory = cat
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 18))
                            Text(cat.label)
                                .font(.system(size: 12, weight: searchCategory == cat ? .bold : .medium, design: .rounded))
                        }
                        .foregroundStyle(searchCategory == cat ? IRLColors.oceanBlue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(searchCategory == cat ? IRLColors.oceanBlue.opacity(0.1) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Search results area
            VStack(spacing: 14) {
                Image(systemName: searchCategory.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(IRLColors.oceanBlue.opacity(0.4))

                Text(searchCategory.searchTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)

                Text(searchCategory.searchSubtitle)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if searchCategory == .location {
                    // Mini globe showing activity
                    EarthView(autoRotate: true, pins: allPostLocations)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: IRLColors.oceanBlue.opacity(0.2), radius: 20)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.5))
            Text("No moments yet.")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("Be the first to share.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

// MARK: - Feed Post Card

private struct FeedPostCard: View {

    let post: Post
    let postStore: PostStore
    var onWhyTapped: (() -> Void)?

    @State private var showFullCaption = false
    @State private var reactions: [String: Int] = [:]
    @State private var myReactions: Set<String> = []
    @State private var showReactionBar = false
    @State private var showMoreEmojis = false

    // Path-inspired primary reactions
    private let quickReactions = ["❤️", "😂", "😮", "😢", "🔥"]
    // Extended set
    private let moreEmojis = ["😍", "🙌", "💯", "🌍", "✨", "🤯", "👏", "🥺", "💪", "🫶", "🎉", "💀", "😭", "🤩", "🙏", "👀"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author row
            HStack(spacing: 10) {
                PostAvatarView(authorId: post.authorId)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.authorName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                    HStack(spacing: 4) {
                        Text(post.createdAt.relativeFormatted)
                        if post.location != nil {
                            Text("·")
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                // Trust badge
                TrustBadgeView(level: post.trustLevel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Media — edge to edge, no padding, no rounding
            mediaContent

            // Actions + Caption
            VStack(alignment: .leading, spacing: 8) {
                // Existing reaction chips
                if !reactions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(reactions.sorted(by: { $0.key < $1.key }), id: \.key) { emoji, count in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    toggleReaction(emoji)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(emoji)
                                        .font(.system(size: 16))
                                    Text("\(count)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(myReactions.contains(emoji) ? IRLColors.oceanBlue : IRLColors.primaryText.opacity(0.7))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(myReactions.contains(emoji) ? IRLColors.oceanBlue.opacity(0.15) : .white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(myReactions.contains(emoji) ? IRLColors.oceanBlue.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Reaction drawer
                if showReactionBar {
                    VStack(spacing: 8) {
                        // Quick reactions
                        HStack(spacing: 12) {
                            ForEach(Array(quickReactions.enumerated()), id: \.element) { index, emoji in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                        toggleReaction(emoji)
                                    }
                                    // Auto-close after picking
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            showReactionBar = false
                                            showMoreEmojis = false
                                        }
                                    }
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .scaleEffect(myReactions.contains(emoji) ? 1.15 : 1.0)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.1).combined(with: .opacity)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.04)),
                                        removal: .scale(scale: 0.5).combined(with: .opacity)
                                            .animation(.easeOut(duration: 0.15))
                                    )
                                )
                            }

                            Rectangle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 1, height: 24)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showMoreEmojis.toggle()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .rotationEffect(.degrees(showMoreEmojis ? 45 : 0))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        if showMoreEmojis {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 8) {
                                ForEach(moreEmojis, id: \.self) { emoji in
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                            toggleReaction(emoji)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                showReactionBar = false
                                                showMoreEmojis = false
                                            }
                                        }
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 26))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity)
                    ))
                }

                // Action row — react button + send + info
                HStack(spacing: 16) {
                    // React button — opens the Path-style bar
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showReactionBar.toggle()
                            if !showReactionBar { showMoreEmojis = false }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showReactionBar ? "face.smiling.fill" : "face.smiling")
                                .font(.system(size: 22))
                            if reactions.isEmpty && !showReactionBar {
                                Text("React")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                        }
                        .foregroundStyle(showReactionBar ? IRLColors.oceanBlue : IRLColors.primaryText)
                    }
                    .buttonStyle(.plain)

                    Button {} label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 20))
                            .foregroundStyle(IRLColors.primaryText)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Why this post — transparency
                    if let onWhyTapped {
                        Button { onWhyTapped() } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    HStack(spacing: 4) {
                        Text(post.authorName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(caption)
                            .font(.system(size: 14, design: .rounded))
                    }
                    .foregroundStyle(IRLColors.primaryText)
                    .lineLimit(showFullCaption ? nil : 2)
                    .onTapGesture { showFullCaption.toggle() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 16)

            // Separator
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)
        }
        .background {
            // Tap anywhere to dismiss emoji drawer
            if showReactionBar {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReactionBar = false
                            showMoreEmojis = false
                        }
                    }
            }
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaContent: some View {
        switch post.mediaType {
        case .photo:
            photoView
        case .video, .short:
            videoView
        }
    }

    private var photoView: some View {
        Group {
            if let uiImage = postStore.loadImage(filename: post.mediaFilename) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width / max(post.aspectRatio, 0.5))
                        .clipped()
                }
                .aspectRatio(max(post.aspectRatio, 0.5), contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(white: 0.08))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .tint(.white.opacity(0.3))
                    }
            }
        }
    }

    @ViewBuilder
    private var videoView: some View {
        VideoThumbnailView(post: post, postStore: postStore)
    }

    // MARK: - Reactions

    private func toggleReaction(_ emoji: String) {
        if myReactions.contains(emoji) {
            myReactions.remove(emoji)
            if let current = reactions[emoji], current > 1 {
                reactions[emoji] = current - 1
            } else {
                reactions.removeValue(forKey: emoji)
            }
        } else {
            myReactions.insert(emoji)
            reactions[emoji, default: 0] += 1
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {

    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Video Thumbnail

private struct VideoThumbnailView: View {

    let post: Post
    let postStore: PostStore
    @State private var showFullscreenPlayer = false

    var body: some View {
        ZStack {
            thumbnailImage
                .overlay {
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(IRLColors.primaryText)
                                .offset(x: 2)
                        }
                }
                .onTapGesture { showFullscreenPlayer = true }
        }
        .fullScreenCover(isPresented: $showFullscreenPlayer) {
            ZStack(alignment: .topLeading) {
                FullscreenVideoPlayerController(
                    url: PostStore.mediaURL(for: post.mediaFilename),
                    isPresented: $showFullscreenPlayer
                )
                .ignoresSafeArea()

                Button {
                    showFullscreenPlayer = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .padding(16)
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumbFilename = post.thumbnailFilename,
           let uiImage = postStore.loadImage(filename: thumbFilename) {
            GeometryReader { geo in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width / max(post.aspectRatio, 0.5))
                    .clipped()
            }
            .aspectRatio(max(post.aspectRatio, 0.5), contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color(white: 0.08))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.2))
                }
        }
    }
}

// MARK: - Fullscreen Video Player (UIViewControllerRepresentable)

struct FullscreenVideoPlayerController: UIViewControllerRepresentable {

    let url: URL
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        controller.modalPresentationStyle = .fullScreen
        controller.allowsPictureInPicturePlayback = false
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - Relative Date

private extension Date {
    var relativeFormatted: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "just now" }
        else if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        else if interval < 172800 { return "yesterday" }
        else { return "\(Int(interval / 86400))d ago" }
    }
}

// MARK: - Post Avatar

private struct PostAvatarView: View {
    let authorId: String

    var body: some View {
        ZStack {
            if authorId == "me",
               let data = UserDefaults.standard.data(forKey: "irl_profile_photo"),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(IRLColors.earthGradient, lineWidth: 1.5)
                    )
            } else {
                EarthView(autoRotate: false)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(IRLColors.earthGradient, lineWidth: 1.5)
                    )
            }
        }
    }
}

// MARK: - Why This Post

private struct WhyThisPostView: View {
    let post: Post
    let feedFilter: FeedFilter

    var body: some View {
        VStack(spacing: 20) {
            Text("Why this post?")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 14) {
                transparencyRow(icon: "person.fill", label: "Author", value: post.authorName)
                transparencyRow(icon: feedFilter.icon, label: "Feed filter", value: feedFilter.label)
                transparencyRow(icon: "clock", label: "Posted", value: post.createdAt.formatted(date: .abbreviated, time: .shortened))
                transparencyRow(icon: "checkmark.seal.fill", label: "Content", value: "Verified real — not AI generated")
                transparencyRow(icon: "eye", label: "Reason shown", value: reasonText)
                transparencyRow(icon: "hand.raised.fill", label: "Your data", value: "No tracking. No profiling. No selling.")
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("IRL will never show you content designed to manipulate you.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.08).ignoresSafeArea())
        // theme controlled globally from IRLApp
    }

    private var reasonText: String {
        switch feedFilter {
        case .friends: return "You follow this person"
        case .interests: return "Matches your interests"
        case .both: return "Friend or interest match"
        }
    }

    private func transparencyRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(IRLColors.oceanBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
            }
        }
    }
}

// MARK: - Feed Transparency Settings

private struct FeedTransparencyView: View {
    @Binding var feedFilter: FeedFilter
    @Binding var sortOrder: FeedSort
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your feed, your rules.")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(IRLColors.primaryText)
                        Text("IRL gives you full control over what you see. No hidden algorithms, no engagement tricks, no manipulation.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // What you're seeing
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("What you see")

                        ForEach(FeedFilter.allCases, id: \.self) { filter in
                            Button {
                                feedFilter = filter
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: filter.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(IRLColors.oceanBlue)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(filter.label)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(IRLColors.primaryText)
                                        Text(filter.transparencyDescription)
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }

                                    Spacer()

                                    if feedFilter == filter {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(IRLColors.earthGreen)
                                    }
                                }
                                .padding(14)
                                .background(feedFilter == filter ? .white.opacity(0.06) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Sort order
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Sort order")

                        ForEach(FeedSort.allCases, id: \.self) { sort in
                            Button {
                                sortOrder = sort
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: sort.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(IRLColors.oceanBlue)
                                        .frame(width: 28)

                                    Text(sort.label)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(IRLColors.primaryText)

                                    Spacer()

                                    if sortOrder == sort {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(IRLColors.earthGreen)
                                    }
                                }
                                .padding(14)
                                .background(sortOrder == sort ? .white.opacity(0.06) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Transparency promise
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Our promise")

                        VStack(alignment: .leading, spacing: 14) {
                            promiseRow(icon: "eye.slash", text: "We never track what you look at or how long")
                            promiseRow(icon: "chart.bar.xaxis", text: "We never optimize for engagement or addiction")
                            promiseRow(icon: "dollarsign.circle", text: "We never sell your data or show you ads")
                            promiseRow(icon: "brain", text: "We never use AI to decide what you should see")
                            promiseRow(icon: "clock", text: "Chronological is always available — your default")
                        }
                        .padding(16)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Feed Transparency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(Color(white: 0.06), for: .navigationBar)
        }
        // theme controlled globally from IRLApp
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.3))
            .tracking(1)
    }

    private func promiseRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(IRLColors.earthGreen)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(PostStore())
}
