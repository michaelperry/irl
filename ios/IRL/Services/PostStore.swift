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
        let postLocation = loc.map { PostLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }

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
    }

    // MARK: - Save video

    func saveVideo(sourceURL: URL, duration: TimeInterval, caption: String? = nil) {
        let isShort = duration < 60
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
        let postLocation = loc.map { PostLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }

        let post = Post(
            mediaType: isShort ? .short : .video,
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
        posts = decoded
        myPosts = decoded.filter { $0.authorId == "me" }
    }
}
