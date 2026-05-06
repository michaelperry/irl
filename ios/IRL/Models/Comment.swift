import Foundation

struct Comment: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let parentCommentId: String?
    let encryptedContent: String
    let createdAt: String
    /// Sealed key envelope addressed to the requesting user, if any. Nil for plaintext fallback.
    let myEnvelope: String?

    /// Plaintext, decrypted client-side after fetch. Not part of server payload.
    var decryptedContent: String?

    enum CodingKeys: String, CodingKey {
        case id, postId, userId, parentCommentId, encryptedContent, createdAt, myEnvelope
    }
}

enum ReportReason: String, CaseIterable, Codable {
    case harassment
    case sexual
    case violence
    case selfHarm = "self_harm"
    case spam
    case impersonation
    case other

    var label: String {
        switch self {
        case .harassment:    return "Harassment or bullying"
        case .sexual:        return "Sexual content"
        case .violence:      return "Violence or threats"
        case .selfHarm:      return "Self-harm or suicide"
        case .spam:          return "Spam"
        case .impersonation: return "Impersonation"
        case .other:         return "Something else"
        }
    }

    var icon: String {
        switch self {
        case .harassment:    return "exclamationmark.bubble"
        case .sexual:        return "eye.slash"
        case .violence:      return "exclamationmark.triangle"
        case .selfHarm:      return "heart.slash"
        case .spam:          return "tray.full"
        case .impersonation: return "person.crop.circle.badge.questionmark"
        case .other:         return "ellipsis.circle"
        }
    }
}

enum ReportTargetType: String, Codable {
    case post
    case comment
    case user
}
