import Foundation

struct Story: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let authorName: String
    let encryptedContent: String?
    let encryptedMediaUrl: String?
    let encryptedMediaKey: String?
    let mediaType: String?     // "photo" | "video" — defaults to photo when absent
    let trustLevel: String
    let createdAt: String
    let expiresAt: String
    let myEnvelope: String?
    let viewed: Bool

    var isVideo: Bool { mediaType == "video" }
}

struct StoryGroup: Identifiable, Codable, Hashable {
    var id: String { authorId }
    let authorId: String
    let authorName: String
    let stories: [Story]
    let hasUnseen: Bool
}
