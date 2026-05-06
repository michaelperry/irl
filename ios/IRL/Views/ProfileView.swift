import SwiftUI
import UIKit
import AVKit
import PhotosUI

// MARK: - Profile View

struct ProfileView: View {

    @EnvironmentObject var postStore: PostStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService

    @State private var selectedPost: Post?
    @State private var isEditingName = false
    @State private var displayName: String = UserDefaults.standard.string(forKey: "irl_display_name") ?? ""
    @State private var profileImage: UIImage? = {
        guard let data = UserDefaults.standard.data(forKey: "irl_profile_photo") else { return nil }
        return UIImage(data: data)
    }()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showSettings = false
    @State private var showInvite = false
    @State private var showWorldMap = false
    @State private var profileMe: APIClient.ProfileResponse?
    @State private var invites: [Invite] = []
    @AppStorage("irl_show_pins") private var showPinsOnGlobe = true

    private var postLocations: [PostLocation] {
        postStore.myPosts.compactMap { $0.location }
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    statsRow
                        .padding(.top, 56)
                    friendCircleSection
                        .padding(.top, 16)
                    photoGrid
                        .padding(.top, 20)
                    signOutButton
                        .padding(.top, 32)
                    Spacer(minLength: 60)
                }
                .task { await loadCircle() }
                .refreshable { await loadCircle() }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(IRLColors.primaryText.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedPost) { post in
                PostDetailView(post: post, postStore: postStore)
            }
            .fullScreenCover(isPresented: $showWorldMap) {
                WorldMapView(posts: postStore.myPosts, postStore: postStore)
            }
            .sheet(isPresented: $showInvite) {
                InviteFriendView(onChange: { Task { await loadCircle() } })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authService)
                    .environmentObject(screenTimeService)
                    .presentationDragIndicator(.visible)
            }
        }
        // theme controlled globally from IRLApp
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    profileImage = uiImage
                    // Save as JPEG to UserDefaults
                    if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                        UserDefaults.standard.set(jpegData, forKey: "irl_profile_photo")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Earth banner — tap to open interactive map
            EarthView(autoRotate: false, pins: showPinsOnGlobe ? postLocations : [])
                .frame(height: 200)
                .clipped()
                .onTapGesture { showWorldMap = true }
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.3),
                            .init(color: IRLColors.deepSpace.opacity(0.6), location: 0.65),
                            .init(color: IRLColors.deepSpace, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Profile content overlaid
            VStack(spacing: 12) {
                profileAvatar
                nameSection
            }
            .offset(y: 50)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Avatar

    private var profileAvatar: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            ZStack {
                // Outer gradient ring
                Circle()
                    .stroke(IRLColors.earthGradient, lineWidth: 3.5)
                    .frame(width: 100, height: 100)

                // Inner photo or placeholder
                Group {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        EarthView(autoRotate: true)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(Circle())

                // Camera badge
                Circle()
                    .fill(IRLColors.oceanBlue)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(IRLColors.deepSpace, lineWidth: 2.5)
                    )
                    .offset(x: 34, y: 34)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Name

    private var nameSection: some View {
        Group {
            if isEditingName {
                TextField("Your name", text: $displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .onSubmit {
                        isEditingName = false
                        UserDefaults.standard.set(displayName, forKey: "irl_display_name")
                    }
            } else {
                Text(resolvedDisplayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                    .onTapGesture {
                        isEditingName = true
                    }
            }
        }
    }

    private var resolvedDisplayName: String {
        if !displayName.isEmpty { return displayName }
        return postStore.myPosts.first?.authorName ?? "You"
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(postStore.myPosts.count)", label: "posts")
            statDivider
            friendsStat
            statDivider
            screenTimeStat
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }

    private var friendsStat: some View {
        Button {
            showInvite = true
        } label: {
            VStack(spacing: 4) {
                Text(friendsStatValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                Text("friends")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var friendsStatValue: String {
        guard let me = profileMe else { return "—" }
        let limit = me.friendLimit ?? 50
        return "\(me.following)/\(limit)"
    }

    private var screenTimeStat: some View {
        VStack(spacing: 6) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 24, height: 24)
                Circle()
                    .trim(from: 0, to: max(0, 1 - screenTimeService.progress))
                    .stroke(
                        screenTimeColor.gradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
            }
            Text(screenTimeService.remainingFormatted)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(screenTimeColor)
            Text("remaining")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Friend Circle Section

    private var friendCircleSection: some View {
        Button {
            showInvite = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your circle")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(0.5)
                        Text(circleHeadline)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(IRLColors.primaryText)
                    }
                    Spacer()
                    if pendingInviteCount > 0 {
                        pendingChip
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                CircleDotsRow(
                    filled: profileMe?.following ?? 0,
                    base: profileMe?.friendLimit.map { $0 - (profileMe?.bonusSlotsUnlocked ?? 0) } ?? 50,
                    bonusUnlocked: profileMe?.bonusSlotsUnlocked ?? 0,
                    bonusMax: profileMe?.bonusSlotsMax ?? 5
                )

                if let subtitle = circleSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var circleHeadline: String {
        guard let me = profileMe else { return "—" }
        let bonus = me.bonusSlotsUnlocked ?? 0
        if bonus > 0 {
            return "\(me.following) of \(me.friendLimit ?? 50)  ·  +\(bonus) bonus"
        }
        return "\(me.following) of \(me.friendLimit ?? 50)"
    }

    private var circleSubtitle: String? {
        guard let me = profileMe else { return nil }
        let bonus = me.bonusSlotsUnlocked ?? 0
        let maxBonus = me.bonusSlotsMax ?? 5
        let redeemedThisRound = invites.filter { $0.isRedeemed }.count
        if bonus < maxBonus {
            let left = maxBonus - bonus
            return "Invite \(left) more friend\(left == 1 ? "" : "s") to unlock \(left) bonus spot\(left == 1 ? "" : "s")."
        }
        if redeemedThisRound > 0 {
            return "All bonus spots unlocked. Real-life sized, plus 5."
        }
        return nil
    }

    private var pendingInviteCount: Int {
        invites.filter { !$0.isRedeemed }.count
    }

    private var pendingChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "envelope.badge").font(.system(size: 11))
            Text("\(pendingInviteCount) pending")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(IRLColors.oceanBlue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(IRLColors.oceanBlue.opacity(0.12))
        .clipShape(Capsule())
    }

    private func loadCircle() async {
        async let me = try? APIClient.shared.getProfile()
        async let inv = try? APIClient.shared.listMyInvites()
        let (m, i) = await (me, inv)
        await MainActor.run {
            if let m { self.profileMe = m }
            if let i { self.invites = i }
        }
    }

    private var screenTimeColor: Color {
        if screenTimeService.progress > 0.9 { return .red }
        if screenTimeService.progress > 0.75 { return .orange }
        return IRLColors.earthGreen
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(IRLColors.primaryText.opacity(0.12))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button { showWorldMap = true } label: {
                HStack {
                    Text("Your World")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                    Spacer()
                    if !postLocations.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text("\(postLocations.count) pins")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(IRLColors.earthGreen)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if postStore.myPosts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Text("Your moments will appear here")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 1) {
                    ForEach(postStore.myPosts) { post in
                        gridThumbnail(for: post)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPost = post
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gridThumbnail(for post: Post) -> some View {
        let thumbnailFilename: String? = {
            switch post.mediaType {
            case .photo:
                return post.mediaFilename
            case .video, .short:
                return post.thumbnailFilename ?? post.mediaFilename
            }
        }()

        GeometryReader { geo in
            ZStack {
                if let filename = thumbnailFilename,
                   let uiImage = postStore.loadImage(filename: filename) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(white: 0.12))
                        .overlay {
                            Image(systemName: post.mediaType == .photo ? "photo" : "video")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white.opacity(0.15))
                        }
                }

                // Video play badge
                if post.mediaType == .video || post.mediaType == .short {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.black.opacity(0.55), in: Circle())
                                .padding(6)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            authService.signOut()
        } label: {
            Text("Sign Out")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.red.opacity(0.7))
        }
        .padding(.top, 16)
    }
}

// MARK: - Circle Dots Row

private struct CircleDotsRow: View {
    let filled: Int        // following count
    let base: Int          // typically 50
    let bonusUnlocked: Int // 0..bonusMax
    let bonusMax: Int      // typically 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Base 50 — 10 cols x 5 rows
            VStack(spacing: 4) {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<perRow, id: \.self) { col in
                            let idx = row * perRow + col
                            dot(filledBaseIndex: idx)
                        }
                    }
                }
            }
            // Bonus — 5 dots inline
            HStack(spacing: 6) {
                Text("BONUS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1.2)
                HStack(spacing: 4) {
                    ForEach(0..<bonusMax, id: \.self) { i in
                        bonusDot(at: i)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private let perRow = 10
    private var rowCount: Int { Int((Double(base) / Double(perRow)).rounded(.up)) }

    @ViewBuilder
    private func dot(filledBaseIndex idx: Int) -> some View {
        if idx >= base {
            Color.clear.frame(width: 8, height: 8)
        } else if idx < min(filled, base) {
            Circle().fill(IRLColors.oceanBlue).frame(width: 8, height: 8)
        } else {
            Circle().fill(.white.opacity(0.12)).frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private func bonusDot(at i: Int) -> some View {
        let unlocked = i < bonusUnlocked
        let used = unlocked && (filled - base) > i
        if used {
            Circle().fill(IRLColors.earthGreen).frame(width: 8, height: 8)
        } else if unlocked {
            Circle()
                .strokeBorder(IRLColors.earthGreen, lineWidth: 1.4)
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2]))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Post Detail (Full Screen)

private struct PostDetailView: View {

    let post: Post
    let postStore: PostStore
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGSize = .zero
    @State private var isEditingCaption = false
    @State private var editedCaption: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.4), in: Circle())
                    }

                    Spacer()

                    Text(post.createdAt, style: .date)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    // Edit/Delete menu
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
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Media
                mediaContent
                    .offset(y: dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 120 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )

                // Caption editing or display
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
                    .padding(.vertical, 12)
                } else if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                Spacer()
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
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch post.mediaType {
        case .photo:
            if let uiImage = postStore.loadImage(filename: post.mediaFilename) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(post.aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 12)
            }
        case .video, .short:
            VideoPlayer(player: AVPlayer(url: PostStore.mediaURL(for: post.mediaFilename)))
                .aspectRatio(post.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
        }
    }
}

// MARK: - Invite Friend

private struct InviteFriendView: View {
    var onChange: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var invites: [Invite] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var presentShare = false
    @State private var shareItems: [Any] = []
    @State private var copiedCode: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerBlock
                    codesList
                    shareAllButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Invite friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .task { await loadOrMint() }
            .sheet(isPresented: $presentShare) {
                ShareActivityView(items: shareItems)
            }
            .alert("Couldn't load invites", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bring your real-life friends.")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)
            Text("Each friend who joins unlocks one bonus slot in your circle, up to 5.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var codesList: some View {
        VStack(spacing: 10) {
            if loading && invites.isEmpty {
                ProgressView().tint(.white).padding(.vertical, 36)
            } else {
                ForEach(invites) { inv in
                    codeRow(inv)
                }
            }
        }
    }

    private func codeRow(_ inv: Invite) -> some View {
        HStack(spacing: 12) {
            Text(inv.code)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(inv.isRedeemed ? .white.opacity(0.35) : IRLColors.primaryText)
                .strikethrough(inv.isRedeemed, color: .white.opacity(0.35))

            Spacer()

            if inv.isRedeemed {
                Label("Redeemed", systemImage: "checkmark.seal.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.earthGreen)
            } else {
                Button {
                    UIPasteboard.general.string = inv.code
                    copiedCode = inv.code
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        await MainActor.run {
                            if copiedCode == inv.code { copiedCode = nil }
                        }
                    }
                } label: {
                    Label(
                        copiedCode == inv.code ? "Copied" : "Copy",
                        systemImage: copiedCode == inv.code ? "checkmark" : "doc.on.doc"
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.oceanBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white.opacity(inv.isRedeemed ? 0.02 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var shareAllButton: some View {
        let liveCodes = invites.filter { !$0.isRedeemed }.map { $0.code }
        return Button {
            let body = inviteShareText(codes: liveCodes)
            shareItems = [body]
            presentShare = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16))
                Text(liveCodes.isEmpty ? "All invites used 🎉" : "Share invites")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(liveCodes.isEmpty ? Color.white.opacity(0.1) : IRLColors.oceanBlue)
            .clipShape(Capsule())
        }
        .disabled(liveCodes.isEmpty)
    }

    private func loadOrMint() async {
        loading = true
        defer { loading = false }
        do {
            // Returns existing live codes + tops up to 5 if needed; idempotent.
            let minted = try await APIClient.shared.mintInvites(count: 5)
            invites = minted
            onChange?()
        } catch {
            // Fall back to listing only (no mint) if we hit a server hiccup
            do {
                invites = try await APIClient.shared.listMyInvites()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func inviteShareText(codes: [String]) -> String {
        guard !codes.isEmpty else { return "" }
        let codeList = codes.joined(separator: ", ")
        return """
        Come join me on IRL — a smaller, safer social network for real friends.

        50 friends max, no ads, end-to-end encrypted. You hold the keys.

        Use one of my invite codes when you sign up: \(codeList)
        """
    }
}

private struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ProfileView()
        .environmentObject(PostStore())
        .environmentObject(AuthService())
        .environmentObject(ScreenTimeService())
}
