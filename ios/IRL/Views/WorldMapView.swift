import SwiftUI
import MapKit
import AVKit
import UIKit

struct WorldMapView: View {
    let posts: [Post]
    let postStore: PostStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCluster: LocationCluster?
    @State private var selectedPost: Post?
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.4, longitude: -119.7), // default to user area
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5) // see neighboring towns
    ))

    private var clusters: [LocationCluster] {
        LocationCluster.clusterPosts(posts)
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(clusters) { cluster in
                    Annotation(
                        cluster.name,
                        coordinate: cluster.coordinate
                    ) {
                        Button {
                            selectedCluster = cluster
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(IRLColors.earthGreen)
                                    .frame(width: pinSize(for: cluster), height: pinSize(for: cluster))
                                    .shadow(color: IRLColors.earthGreen.opacity(0.5), radius: 8)

                                Text("\(cluster.posts.count)")
                                    .font(.system(size: cluster.posts.count > 9 ? 10 : 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()

            // Top bar
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Your World")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("\(posts.filter { $0.location != nil }.count) moments · \(clusters.count) places")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    // Fit all pins
                    Button {
                        withAnimation { cameraPosition = .automatic }
                    } label: {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .sheet(item: $selectedCluster) { cluster in
            ClusterDetailView(cluster: cluster, postStore: postStore, onSelectPost: { post in
                selectedCluster = nil
                selectedPost = post
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $selectedPost) { post in
            FeedPostDetailView2(post: post, postStore: postStore)
        }
        .preferredColorScheme(.dark)
    }

    private func pinSize(for cluster: LocationCluster) -> CGFloat {
        let base: CGFloat = 32
        let extra = min(CGFloat(cluster.posts.count - 1) * 4, 20)
        return base + extra
    }
}

// MARK: - Location Cluster

struct LocationCluster: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let posts: [Post]

    static func clusterPosts(_ posts: [Post]) -> [LocationCluster] {
        var groups: [String: (coordinate: CLLocationCoordinate2D, posts: [Post])] = [:]

        for post in posts {
            guard let loc = post.location else { continue }

            // Round to ~1km grid for clustering
            let latKey = String(format: "%.2f", loc.latitude)
            let lonKey = String(format: "%.2f", loc.longitude)
            let key = "\(latKey),\(lonKey)"

            if var existing = groups[key] {
                existing.posts.append(post)
                groups[key] = existing
            } else {
                let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                groups[key] = (coordinate: coord, posts: [post])
            }
        }

        return groups.map { key, value in
            LocationCluster(name: "📍", coordinate: value.coordinate, posts: value.posts)
        }
        .sorted { $0.posts.count > $1.posts.count }
    }
}

// MARK: - Cluster Detail

private struct ClusterDetailView: View {
    let cluster: LocationCluster
    let postStore: PostStore
    let onSelectPost: (Post) -> Void

    @State private var locationName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                if locationName.isEmpty {
                    Text("Loading...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                } else {
                    Text(locationName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                Text("\(cluster.posts.count) moment\(cluster.posts.count == 1 ? "" : "s") here")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Post grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(cluster.posts) { post in
                        Button { onSelectPost(post) } label: {
                            postThumbnail(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { resolveLocationName() }
    }

    private func postThumbnail(_ post: Post) -> some View {
        GeometryReader { geo in
            if let image = postStore.loadImage(filename: post.mediaFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(white: 0.1))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomTrailing) {
            if post.mediaType == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(4)
            }
        }
    }

    private func resolveLocationName() {
        let location = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let place = placemarks?.first {
                let parts = [place.locality, place.administrativeArea, place.country].compactMap { $0 }
                locationName = parts.prefix(2).joined(separator: ", ")
            } else {
                locationName = "Unknown location"
            }
        }
    }
}

// MARK: - Post Detail from Map

private struct FeedPostDetailView2: View {
    let post: Post
    let postStore: PostStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                    VideoPlayerRepresentable2(player: player)
                        .ignoresSafeArea()
                }
            }

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .onAppear {
            if post.mediaType != .photo {
                player = AVPlayer(url: PostStore.mediaURL(for: post.mediaFilename))
                player?.play()
            }
        }
        .onDisappear { player?.pause() }
    }
}

private struct VideoPlayerRepresentable2: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        return vc
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
