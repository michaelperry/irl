import Combine
import CoreLocation
import Foundation
import SwiftUI
import AVFoundation
import UIKit

final class PostStore: ObservableObject {

    @Published private(set) var posts: [Post] = []
    @Published private(set) var myPosts: [Post] = []

    private let postsKey = "irl_posts"

    init() {
        load()
    }

    // MARK: - Media directories

    static var mediaDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let media = docs.appendingPathComponent("irl_media", isDirectory: true)
        try? FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        return media
    }

    static func mediaURL(for filename: String) -> URL {
        mediaDirectory.appendingPathComponent(filename)
    }

    // MARK: - Save photo

    func savePhoto(image: UIImage, caption: String? = nil, trustLevel: TrustLevel = .verified) {
        let filename = "\(UUID().uuidString).jpg"
        let url = Self.mediaURL(for: filename)

        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url)

        let aspectRatio = Double(image.size.width / image.size.height)
        let loc = LocationService.shared.currentLocation
        let postLocation = loc.map { PostLocation.fuzzy(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }

        let post = Post(
            mediaType: .photo,
            mediaFilename: filename,
            caption: caption,
            aspectRatio: aspectRatio,
            location: postLocation,
            trustLevel: trustLevel
        )

        posts.insert(post, at: 0)
        myPosts.insert(post, at: 0)
        persist()

        // Sync to server in background
        Task {
            await uploadPostToServer(post: post, imageData: data)
        }
    }

    // MARK: - Save video

    func saveVideo(sourceURL: URL, duration: TimeInterval, caption: String? = nil) {
        let filename = "\(UUID().uuidString).mov"
        let destURL = Self.mediaURL(for: filename)

        try? FileManager.default.copyItem(at: sourceURL, to: destURL)

        // Generate thumbnail
        let thumbFilename = "\(UUID().uuidString)_thumb.jpg"
        let thumbURL = Self.mediaURL(for: thumbFilename)
        if let thumb = generateThumbnail(for: destURL) {
            try? thumb.jpegData(compressionQuality: 0.8)?.write(to: thumbURL)
        }

        let asset = AVURLAsset(url: destURL)
        let tracks = asset.tracks(withMediaType: .video)
        let size = tracks.first?.naturalSize ?? CGSize(width: 1, height: 1)
        let aspectRatio = Double(size.width / size.height)

        let loc = LocationService.shared.currentLocation
        let postLocation = loc.map { PostLocation.fuzzy(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }

        let post = Post(
            mediaType: .video,
            mediaFilename: filename,
            thumbnailFilename: thumbFilename,
            caption: caption,
            aspectRatio: aspectRatio,
            location: postLocation
        )

        posts.insert(post, at: 0)
        myPosts.insert(post, at: 0)
        persist()
    }

    // MARK: - Thumbnail

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    // MARK: - Load image helper

    // MARK: - Delete post

    func deletePost(_ post: Post) {
        // Delete media files
        let mediaURL = Self.mediaURL(for: post.mediaFilename)
        try? FileManager.default.removeItem(at: mediaURL)
        if let thumb = post.thumbnailFilename {
            try? FileManager.default.removeItem(at: Self.mediaURL(for: thumb))
        }

        posts.removeAll { $0.id == post.id }
        myPosts.removeAll { $0.id == post.id }
        persist()

        // Best-effort server delete — local removal is the source of truth from the user's POV.
        if let serverId = post.serverId {
            Task {
                do {
                    try await APIClient.shared.deletePost(serverId: serverId)
                } catch {
                    print("[IRL] server delete post failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Update caption

    func updateCaption(for postId: UUID, newCaption: String?) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let old = posts[index]
            let updated = Post(
                serverId: old.serverId,
                authorId: old.authorId,
                authorName: old.authorName,
                mediaType: old.mediaType,
                mediaFilename: old.mediaFilename,
                thumbnailFilename: old.thumbnailFilename,
                caption: newCaption,
                aspectRatio: old.aspectRatio,
                location: old.location,
                trustLevel: old.trustLevel
            )
            // Preserve original id and date
            posts[index] = updated
        }
        if let index = myPosts.firstIndex(where: { $0.id == postId }) {
            let old = myPosts[index]
            let updated = Post(
                serverId: old.serverId,
                authorId: old.authorId,
                authorName: old.authorName,
                mediaType: old.mediaType,
                mediaFilename: old.mediaFilename,
                thumbnailFilename: old.thumbnailFilename,
                caption: newCaption,
                aspectRatio: old.aspectRatio,
                location: old.location,
                trustLevel: old.trustLevel
            )
            myPosts[index] = updated
        }
        persist()
    }

    // MARK: - Load image helper

    func loadImage(filename: String) -> UIImage? {
        let url = Self.mediaURL(for: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(data, forKey: postsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: postsKey),
              let decoded = try? JSONDecoder().decode([Post].self, from: data) else { return }
        // Fuzz any existing precise locations to city level
        posts = decoded.map { post in
            guard let loc = post.location else { return post }
            let fuzzed = PostLocation.fuzzy(latitude: loc.latitude, longitude: loc.longitude)
            if fuzzed.latitude == loc.latitude && fuzzed.longitude == loc.longitude { return post }
            return Post(
                serverId: post.serverId,
                authorId: post.authorId, authorName: post.authorName,
                mediaType: post.mediaType, mediaFilename: post.mediaFilename,
                thumbnailFilename: post.thumbnailFilename, caption: post.caption,
                aspectRatio: post.aspectRatio, location: fuzzed, trustLevel: post.trustLevel
            )
        }
        myPosts = posts.filter { $0.authorId == "me" }
        persist() // Save fuzzed versions
    }

    // MARK: - Server Sync

    private func uploadPostToServer(post: Post, imageData: Data) async {
        guard KeychainService.isLoggedIn else { return }

        // Encode image as base64 for server storage (temporary approach)
        // In production, this would upload to blob storage
        let base64 = imageData.base64EncodedString()

        let contentJson: [String: Any] = [
            "caption": post.caption ?? "",
            "mediaType": post.mediaType.rawValue,
            "trustLevel": post.trustLevel.rawValue,
            "aspectRatio": post.aspectRatio,
            "location": post.location.map { ["lat": $0.latitude, "lon": $0.longitude] } as Any,
        ]

        let contentString = (try? JSONSerialization.data(withJSONObject: contentJson))
            .flatMap { String(data: $0, encoding: .utf8) }

        do {
            let serverPost = try await APIClient.shared.createPost(
                content: contentString,
                mediaBase64: base64,
                mediaKey: nil
            )
            await MainActor.run { setServerId(serverPost.id, for: post.id) }
            print("[IRL] Post synced to server (\(serverPost.id))")
        } catch {
            print("[IRL] Failed to sync post: \(error.localizedDescription)")
            // Post is saved locally — will retry on next launch
        }
    }

    private func setServerId(_ serverId: String, for localId: UUID) {
        if let i = posts.firstIndex(where: { $0.id == localId }) {
            posts[i].serverId = serverId
        }
        if let i = myPosts.firstIndex(where: { $0.id == localId }) {
            myPosts[i].serverId = serverId
        }
        persist()
    }

    /// Fetch posts from server and merge with local
    func syncFromServer() async {
        guard KeychainService.isLoggedIn else { return }

        do {
            let feed = try await APIClient.shared.getFeed(limit: 50)
            print("[IRL] Fetched \(feed.posts.count) posts from server")
            // Server posts will be integrated when we build the full sync layer
        } catch {
            print("[IRL] Feed sync failed: \(error.localizedDescription)")
        }
    }
}
