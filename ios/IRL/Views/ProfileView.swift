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
                    photoGrid
                        .padding(.top, 20)
                    signOutButton
                        .padding(.top, 32)
                    Spacer(minLength: 60)
                }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(IRLColors.primaryText)
                            .padding(10)
                            .background(IRLColors.cardBackground, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(IRLColors.primaryText.opacity(0.15), lineWidth: 1)
                            )
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
                InviteFriendView()
                    .presentationDetents([.medium])
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
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(IRLColors.oceanBlue)
                }
                Text("Invite")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.oceanBlue)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Earth globe
            EarthView(autoRotate: true)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .padding(.top, 24)

            Text("Invite a friend to IRL")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(IRLColors.primaryText)

            Text("IRL is better with real people. Share your invite and start building your world together.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Share button
            ShareLink(item: "Join me on IRL — the safest place on the internet. No ads, no bots, fully encrypted. Download here: https://irl.earth") {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Share Invite")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(IRLColors.oceanBlue)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 32)

            // Copy link
            Button {
                UIPasteboard.general.string = "https://irl.earth/invite"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                    Text("Copy invite link")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(IRLColors.oceanBlue)
            }

            Spacer()
        }
        .background(IRLColors.deepSpace.ignoresSafeArea())
    }
}

#Preview {
    ProfileView()
        .environmentObject(PostStore())
        .environmentObject(AuthService())
        .environmentObject(ScreenTimeService())
}
