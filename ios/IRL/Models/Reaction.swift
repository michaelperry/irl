import Foundation

/// Path-inspired fixed reaction set. Keep small and expressive — server enforces the same kinds.
enum ReactionKind: String, CaseIterable, Codable {
    case smile
    case love
    case wow
    case sad
    case laugh
    case fire

    var emoji: String {
        switch self {
        case .smile: return "😊"
        case .love:  return "❤️"
        case .wow:   return "😮"
        case .sad:   return "😢"
        case .laugh: return "😂"
        case .fire:  return "🔥"
        }
    }

    static func from(emoji: String) -> ReactionKind? {
        ReactionKind.allCases.first { $0.emoji == emoji }
    }
}

struct ReactionSummary: Codable {
    var counts: [String: Int]   // keyed by kind raw value
    var mine: String?           // kind raw value or nil

    static let empty = ReactionSummary(counts: [:], mine: nil)

    var myKind: ReactionKind? { mine.flatMap(ReactionKind.init(rawValue:)) }
}
