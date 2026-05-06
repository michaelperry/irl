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
    @State private var showWorldMap = false
    @State private var searchResults: [APIClient.SearchUser] = []
    @State private var searchInFlight = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var unreadActivity: Int = 0
    @State private var showActivity = false
    @State private var unreadMessages: Int = 0
    @State private var showMessages = false
    @State private var storyGroups: [StoryGroup] = []
    @State private var viewerGroupIndex: Int?
    @State private var showStoryComposer = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if !searchText.isEmpty {
                    searchPlaceholder
                } else {
                    StoryRingsBar(
                        groups: storyGroups,
                        onTapGroup: { group in
                            if let i = storyGroups.firstIndex(where: { $0.authorId == group.authorId }) {
                                viewerGroupIndex = i
                            }
                        },
                        onTapAddOwn: { showStoryComposer = true }
                    )

                    if filteredPosts.isEmpty {
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
            }
            .refreshable {
                await postStore.syncFromServer()
                await refreshStories()
                await refreshUnread()
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search people, interests, or places...")
            .onChange(of: searchText) { _, newValue in
                triggerSearch(for: newValue)
            }
            .onChange(of: searchCategory) { _, _ in
                triggerSearch(for: searchText)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showWorldMap = true } label: {
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
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showMessages = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 16))
                                .foregroundStyle(IRLColors.primaryText)
                                .frame(width: 32, height: 32)
                            if unreadMessages > 0 {
                                Text(unreadMessages > 99 ? "99+" : "\(unreadMessages)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(IRLColors.oceanBlue)
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -2)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showActivity = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                                .foregroundStyle(IRLColors.primaryText)
                                .frame(width: 32, height: 32)
                            if unreadActivity > 0 {
                                Text(unreadActivity > 99 ? "99+" : "\(unreadActivity)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -2)
                            }
                        }
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

                        // World map
                        Button {
                            showWorldMap = true
                        } label: {
                            Label("Explore Pins", systemImage: "map.fill")
                        }

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
            .task {
                await refreshUnread()
                await refreshStories()
                await postStore.syncFromServer()
            }
            .refreshable { await refreshStories() }
            .onChange(of: showActivity) { _, isOpen in
                if !isOpen { Task { await refreshUnread() } }
            }
            .onChange(of: showMessages) { _, isOpen in
                if !isOpen { Task { await refreshUnread() } }
            }
            .sheet(isPresented: $showActivity) {
                ActivitySheet(onDismiss: { showActivity = false })
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showMessages) {
                MessagesInboxSheet(onDismiss: { showMessages = false })
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStoryComposer) {
                StoryComposerSheet(onPublished: { Task { await refreshStories() } })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: Binding(
                get: { viewerGroupIndex.map { ViewerHandle(index: $0) } },
                set: { viewerGroupIndex = $0?.index }
            )) { handle in
                if storyGroups.indices.contains(handle.index) {
                    StoryViewer(
                        group: storyGroups[handle.index],
                        onClose: { viewerGroupIndex = nil },
                        onAdvanceGroup: {
                            let next = handle.index + 1
                            viewerGroupIndex = next < storyGroups.count ? next : nil
                        },
                        onPreviousGroup: {
                            let prev = handle.index - 1
                            if prev >= 0 { viewerGroupIndex = prev } else { viewerGroupIndex = nil }
                        }
                    )
                }
            }
            .fullScreenCover(isPresented: $showWorldMap) {
                WorldMapView(posts: postStore.posts, postStore: postStore)
            }
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
        // The server feed already restricts to people you follow + your own posts,
        // so "friends" effectively means everything we have. "interests" is a
        // future surface (algorithmic / topic-based) — empty for now.
        switch feedFilter {
        case .friends, .both:
            return postStore.allFeedPosts
        case .interests:
            return []
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
            if searchCategory == .friends {
                friendsSearchResults
            } else {
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
                        EarthView(autoRotate: true, pins: allPostLocations)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(color: IRLColors.oceanBlue.opacity(0.2), radius: 20)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var friendsSearchResults: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(IRLColors.oceanBlue.opacity(0.4))
                Text("Type a name")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                Text("At least 2 characters to find someone.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
        } else if searchInFlight && searchResults.isEmpty {
            ProgressView().tint(.white).padding(.top, 32)
        } else if let err = searchError {
            Text(err)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.red.opacity(0.85))
                .padding(.top, 24)
        } else if searchResults.isEmpty {
            VStack(spacing: 6) {
                Text("No matches")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                Text("Try the exact start of their name.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { user in
                    UserSearchRow(user: user) { didFollow in
                        if didFollow {
                            if let i = searchResults.firstIndex(where: { $0.id == user.id }) {
                                searchResults[i] = APIClient.SearchUser(
                                    id: user.id,
                                    displayName: user.displayName,
                                    encryptionPublicKey: user.encryptionPublicKey,
                                    isFollowing: true
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func refreshUnread() async {
        async let activity = try? await APIClient.shared.unreadActivityCount()
        async let messages = try? await APIClient.shared.unreadMessageCount()
        let (a, m) = await (activity, messages)
        await MainActor.run {
            if let a { unreadActivity = a }
            if let m { unreadMessages = m }
        }
    }

    private func refreshStories() async {
        if let groups = try? await APIClient.shared.getStoryGroups() {
            await MainActor.run { storyGroups = groups }
        }
    }

    private func triggerSearch(for text: String) {
        searchTask?.cancel()
        searchError = nil
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        guard searchCategory == .friends, trimmed.count >= 2 else {
            searchResults = []
            searchInFlight = false
            return
        }

        searchInFlight = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            do {
                let users = try await APIClient.shared.searchUsers(query: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    searchResults = users
                    searchInFlight = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    searchError = error.localizedDescription
                    searchInFlight = false
                }
            }
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
    @State private var reactionCounts: [ReactionKind: Int] = [:]
    @State private var myReaction: ReactionKind?
    @State private var showReactionBar = false
    @State private var showPostDetail = false
    @State private var showComments = false
    @State private var showReportSheet = false
    @State private var showBlockConfirm = false

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

            // Media — edge to edge, tappable for detail.
            // Using a Button (not .onTapGesture) gives proper LazyVStack hit-testing
            // and avoids inter-row gesture bleed onto the action row below.
            Button { showPostDetail = true } label: {
                mediaContent
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showPostDetail) {
                FeedPostDetailView(post: post, postStore: postStore)
            }

            // Actions + Caption
            VStack(alignment: .leading, spacing: 8) {
                // Reaction chips — one per kind that has at least 1
                let nonEmpty = ReactionKind.allCases.filter { (reactionCounts[$0] ?? 0) > 0 }
                if !nonEmpty.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(nonEmpty, id: \.self) { kind in
                            let isMine = myReaction == kind
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    setReaction(kind)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(kind.emoji).font(.system(size: 16))
                                    Text("\(reactionCounts[kind] ?? 0)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(isMine ? IRLColors.oceanBlue : IRLColors.primaryText.opacity(0.7))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isMine ? IRLColors.oceanBlue.opacity(0.15) : .white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isMine ? IRLColors.oceanBlue.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Path-style fixed bar — 6 kinds, single-replace
                if showReactionBar {
                    HStack(spacing: 4) {
                        ForEach(ReactionKind.allCases, id: \.self) { kind in
                            let isMine = myReaction == kind
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                    setReaction(kind)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showReactionBar = false
                                    }
                                }
                            } label: {
                                Text(kind.emoji)
                                    .font(.system(size: 28))
                                    .scaleEffect(isMine ? 1.15 : 1.0)
                                    .frame(width: 44, height: 44)
                                    .background(isMine ? IRLColors.oceanBlue.opacity(0.15) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
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

                // Action row — react button + comment + menu + info
                HStack(spacing: 16) {
                    // React button — opens the Path-style bar
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showReactionBar.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let myReaction {
                                Text(myReaction.emoji).font(.system(size: 22))
                            } else {
                                Image(systemName: showReactionBar ? "face.smiling.fill" : "face.smiling")
                                    .font(.system(size: 22))
                            }
                            if myReaction == nil && reactionCounts.isEmpty && !showReactionBar {
                                Text("React")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                        }
                        .foregroundStyle(showReactionBar || myReaction != nil ? IRLColors.oceanBlue : IRLColors.primaryText)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showComments = true
                    } label: {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 20))
                            .foregroundStyle(IRLColors.primaryText)
                    }
                    .buttonStyle(.plain)

                    if post.authorId != "me" {
                        Menu {
                            Button {
                                showReportSheet = true
                            } label: {
                                Label("Report", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Block \(post.authorName)", systemImage: "person.crop.circle.badge.minus")
                            }
                            Button {
                                Task { try? await APIClient.shared.muteUser(post.authorId) }
                            } label: {
                                Label("Mute", systemImage: "speaker.slash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18))
                                .foregroundStyle(IRLColors.primaryText)
                        }
                    }

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
        .task { await loadReactions() }
        .sheet(isPresented: $showComments) {
            CommentsSheet(postServerId: post.serverId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReportSheet) {
            if let serverId = post.serverId {
                ReportSheet(targetType: .post, targetId: serverId, plaintextEvidence: post.caption)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                pendingSyncSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Block \(post.authorName)?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task { try? await APIClient.shared.blockUser(post.authorId) }
            }
        } message: {
            Text("You won't see their posts or comments, and they won't see yours. You can unblock anyone in Settings.")
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaContent: some View {
        switch post.mediaType {
        case .photo:
            photoView
        case .video:
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

    private func setReaction(_ kind: ReactionKind) {
        let previous = myReaction
        if previous == kind {
            // Tap again on same kind = clear
            myReaction = nil
            reactionCounts[kind] = max(0, (reactionCounts[kind] ?? 0) - 1)
        } else {
            // Replace previous (if any), increment new
            if let previous {
                reactionCounts[previous] = max(0, (reactionCounts[previous] ?? 0) - 1)
            }
            myReaction = kind
            reactionCounts[kind] = (reactionCounts[kind] ?? 0) + 1
        }

        // Sync to server (best-effort). Requires server-backed post.
        guard let serverId = post.serverId else { return }
        let next = myReaction
        Task {
            do {
                if let next {
                    try await APIClient.shared.setReaction(postId: serverId, kind: next)
                } else {
                    try await APIClient.shared.clearReaction(postId: serverId)
                }
            } catch {
                // Roll back on failure
                await MainActor.run { rollback(to: previous) }
            }
        }
    }

    private func rollback(to previous: ReactionKind?) {
        // Recompute counts naively — refetch from server next time view appears
        if let cur = myReaction { reactionCounts[cur] = max(0, (reactionCounts[cur] ?? 0) - 1) }
        if let previous { reactionCounts[previous] = (reactionCounts[previous] ?? 0) + 1 }
        myReaction = previous
    }

    private var pendingSyncSheet: some View {
        VStack(spacing: 14) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 36))
                .foregroundStyle(IRLColors.oceanBlue.opacity(0.6))
            Text("Still syncing this post")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("You can report it once it's synced to the server (usually a few seconds).")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IRLColors.deepSpace.ignoresSafeArea())
    }

    private func loadReactions() async {
        guard let serverId = post.serverId else { return }
        do {
            let summary = try await APIClient.shared.getReactions(postId: serverId)
            await MainActor.run {
                var counts: [ReactionKind: Int] = [:]
                for (raw, n) in summary.counts {
                    if let k = ReactionKind(rawValue: raw) { counts[k] = n }
                }
                self.reactionCounts = counts
                self.myReaction = summary.myKind
            }
        } catch {
            // Silent — local state remains
        }
    }
}

// MARK: - User Search Row

private struct UserSearchRow: View {
    let user: APIClient.SearchUser
    var onFollowed: (Bool) -> Void

    @State private var isFollowing: Bool
    @State private var working = false
    @State private var capError: String?

    init(user: APIClient.SearchUser, onFollowed: @escaping (Bool) -> Void) {
        self.user = user
        self.onFollowed = onFollowed
        _isFollowing = State(initialValue: user.isFollowing)
    }

    var body: some View {
        HStack(spacing: 12) {
            EarthView(autoRotate: false)
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().stroke(IRLColors.earthGradient, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                if let err = capError {
                    Text(err)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.red.opacity(0.85))
                } else if user.encryptionPublicKey == nil {
                    Text("Will fall back to plaintext until they upgrade keys")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            Button { Task { await toggleFollow() } } label: {
                HStack(spacing: 6) {
                    if working { ProgressView().tint(isFollowing ? .white : .black).scaleEffect(0.8) }
                    Text(isFollowing ? "Following" : "Add Friend")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(isFollowing ? .white : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.white.opacity(0.12) : Color.white)
                .clipShape(Capsule())
            }
            .disabled(working)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toggleFollow() async {
        working = true
        capError = nil
        defer { working = false }
        do {
            if isFollowing {
                try await APIClient.shared.unfollowUser(user.id)
                isFollowing = false
                onFollowed(false)
            } else {
                try await APIClient.shared.followUser(user.id)
                isFollowing = true
                onFollowed(true)
            }
        } catch let APIError.serverError(code, message) where code == 409 {
            // Friend cap reached. Surface the inline message inline instead of an alert.
            capError = message.contains("friend_limit_reached")
                ? "Your circle is full. Invite friends to unlock bonus spots."
                : message
        } catch {
            capError = error.localizedDescription
        }
    }
}

// MARK: - Viewer Handle

/// Lets us drive a fullScreenCover off an Int? state.
private struct ViewerHandle: Identifiable, Hashable {
    let index: Int
    var id: Int { index }
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
        Button { showFullscreenPlayer = true } label: {
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
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullscreenPlayer) {
            // AVPlayerViewController already provides a close button + AirPlay
            // controls; the prior custom xmark overlay duplicated the close.
            FullscreenVideoPlayerController(
                url: PostStore.mediaURL(for: post.mediaFilename),
                isPresented: $showFullscreenPlayer
            )
            .ignoresSafeArea()
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
                            .foregroundStyle(IRLColors.secondaryText)
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
                                            .foregroundStyle(IRLColors.secondaryText)
                                    }

                                    Spacer()

                                    if feedFilter == filter {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(IRLColors.earthGreen)
                                    }
                                }
                                .padding(14)
                                .background(feedFilter == filter ? IRLColors.oceanBlue.opacity(0.1) : IRLColors.cardBackground.opacity(0.5))
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
                                .background(sortOrder == sort ? IRLColors.oceanBlue.opacity(0.1) : IRLColors.cardBackground.opacity(0.5))
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
                        .background(IRLColors.cardBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Feed Transparency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
        }
        // theme controlled globally from IRLApp
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(IRLColors.oceanBlue)
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
                .foregroundStyle(IRLColors.primaryText.opacity(0.8))
        }
    }
}

// MARK: - Feed Post Detail (Fullscreen)

private struct FeedPostDetailView: View {
    let post: Post
    let postStore: PostStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isEditingCaption = false
    @State private var editedCaption: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Media
            switch post.mediaType {
            case .photo:
                if let image = postStore.loadImage(filename: post.mediaFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .video:
                if let player {
                    VideoPlayerRepresentable(player: player)
                        .ignoresSafeArea()
                }
            }

            // Overlay controls
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    TrustBadgeView(level: post.trustLevel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())

                    // Edit/Delete menu (only for your posts)
                    if post.authorId == "me" {
                        Menu {
                            Button {
                                editedCaption = post.caption ?? ""
                                isEditingCaption = true
                            } label: {
                                Label("Edit Caption", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Caption
                VStack(alignment: .leading, spacing: 4) {
                    if isEditingCaption {
                        HStack(spacing: 10) {
                            TextField("Edit caption...", text: $editedCaption)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 20))

                            Button {
                                let cap = editedCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                                postStore.updateCaption(for: post.id, newCaption: cap.isEmpty ? nil : cap)
                                isEditingCaption = false
                            } label: {
                                Text("Save")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(IRLColors.oceanBlue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else if let caption = post.caption, !caption.isEmpty {
                        HStack {
                            Text(post.authorName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(caption)
                                .font(.system(size: 15, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                )
            }
        }
        .alert("Delete this post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                postStore.deletePost(post)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this photo/video.")
        }
        .onAppear {
            if post.mediaType == .video {
                let url = PostStore.mediaURL(for: post.mediaFilename)
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

// MARK: - Video Player Controller

private struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.videoGravity = .resizeAspect
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

#Preview {
    FeedView()
        .environmentObject(PostStore())
}
