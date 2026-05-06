import Foundation

struct Activity: Identifiable, Codable {
    let id: String
    let actorId: String
    let actorName: String
    let kind: String          // reaction|comment|follow
    let postId: String?
    let commentId: String?
    let reactionKind: String?
    let readAt: String?
    let createdAt: String

    var isRead: Bool { readAt != nil }

    var headline: String {
        switch kind {
        case "reaction":
            let emoji: String = {
                guard let raw = reactionKind, let parsed = ReactionKind(rawValue: raw) else { return "•" }
                return parsed.emoji
            }()
            return "\(actorName) reacted \(emoji)"
        case "comment":
            return "\(actorName) commented on your post"
        case "follow":
            return "\(actorName) added you as a friend"
        case "post":
            return "\(actorName) just shared a moment"
        case "message":
            return "\(actorName) sent you a message"
        default:
            return "\(actorName) interacted"
        }
    }

    var iconName: String {
        switch kind {
        case "reaction": return "face.smiling.fill"
        case "comment":  return "bubble.left.fill"
        case "follow":   return "person.crop.circle.badge.plus"
        case "post":     return "camera.fill"
        case "message":  return "envelope.fill"
        default:         return "bell.fill"
        }
    }
}
