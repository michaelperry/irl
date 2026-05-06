import Foundation

enum MediaType: String, Codable {
    case photo
    case video

    /// Back-compat decoder: posts persisted before the `.short` collapse stored
    /// "short" as their mediaType. Map that (and any future unknown value) to
    /// .video so a single legacy row can't kill the whole feed.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "photo": self = .photo
        case "video", "short": self = .video
        default: self = .video
        }
    }
}

enum TrustLevel: String, Codable {
    case verified     // In-app camera capture
    case cameraRoll   // Camera roll with EXIF camera data
    case unverified   // Camera roll without camera metadata

    var label: String {
        switch self {
        case .verified: return "Verified Real"
        case .cameraRoll: return "Camera Roll"
        case .unverified: return "Unverified"
        }
    }

    var icon: String {
        switch self {
        case .verified: return "checkmark.seal.fill"
        case .cameraRoll: return "photo.badge.checkmark"
        case .unverified: return "exclamationmark.triangle.fill"
        }
    }
}

struct PostLocation: Codable {
    let latitude: Double
    let longitude: Double

    /// Rounds coordinates to city level (~11km precision).
    /// IRL never stores or shares your precise location.
    static func fuzzy(latitude: Double, longitude: Double) -> PostLocation {
        // Round to 1 decimal place ≈ 11km precision (city level)
        PostLocation(
            latitude: (latitude * 10).rounded() / 10,
            longitude: (longitude * 10).rounded() / 10
        )
    }
}

struct Post: Identifiable, Codable {
    let id: UUID
    var serverId: String?
    let authorId: String
    let authorName: String
    let mediaType: MediaType
    let mediaFilename: String
    let thumbnailFilename: String?
    let caption: String?
    let createdAt: Date
    let aspectRatio: Double
    let location: PostLocation?
    let trustLevel: TrustLevel

    init(
        serverId: String? = nil,
        authorId: String = "me",
        authorName: String = "You",
        mediaType: MediaType,
        mediaFilename: String,
        thumbnailFilename: String? = nil,
        caption: String? = nil,
        aspectRatio: Double = 1.0,
        location: PostLocation? = nil,
        trustLevel: TrustLevel = .verified
    ) {
        self.id = UUID()
        self.serverId = serverId
        self.authorId = authorId
        self.authorName = authorName
        self.mediaType = mediaType
        self.mediaFilename = mediaFilename
        self.thumbnailFilename = thumbnailFilename
        self.caption = caption
        self.createdAt = Date()
        self.aspectRatio = aspectRatio
        self.location = location
        self.trustLevel = trustLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        mediaFilename = try container.decode(String.self, forKey: .mediaFilename)
        thumbnailFilename = try container.decodeIfPresent(String.self, forKey: .thumbnailFilename)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        aspectRatio = try container.decode(Double.self, forKey: .aspectRatio)
        location = try container.decodeIfPresent(PostLocation.self, forKey: .location)
        trustLevel = try container.decodeIfPresent(TrustLevel.self, forKey: .trustLevel) ?? .verified
    }
}
