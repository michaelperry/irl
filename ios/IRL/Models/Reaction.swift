import SwiftUI

/// Path-inspired fixed reaction set. Keep small and expressive — server enforces the same kinds.
enum ReactionKind: String, CaseIterable, Codable {
    case smile
    case love
    case wow
    case sad
    case laugh
    case fire

    /// Native emoji — kept for plaintext contexts (push bodies, activity headlines).
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

    /// Custom IRL glyph — SF Symbol-backed for v1, swappable for hand-drawn shapes later.
    var symbolName: String {
        switch self {
        case .smile: return "face.smiling.fill"
        case .love:  return "heart.fill"
        case .wow:   return "sparkles"
        case .sad:   return "drop.fill"
        case .laugh: return "hands.clap.fill"
        case .fire:  return "flame.fill"
        }
    }

    /// Brand-tinted color per kind — keeps the reaction palette warm and distinctly IRL.
    var tint: Color {
        switch self {
        case .smile: return Color(red: 1.0, green: 0.78, blue: 0.20)  // gold
        case .love:  return Color(red: 1.0, green: 0.35, blue: 0.45)  // warm red
        case .wow:   return Color(red: 0.65, green: 0.55, blue: 1.0)  // lavender
        case .sad:   return Color(red: 0.40, green: 0.65, blue: 1.0)  // ocean
        case .laugh: return Color(red: 1.0, green: 0.65, blue: 0.30)  // amber
        case .fire:  return Color(red: 1.0, green: 0.45, blue: 0.20)  // ember
        }
    }

    static func from(emoji: String) -> ReactionKind? {
        ReactionKind.allCases.first { $0.emoji == emoji }
    }
}

/// Branded reaction icon used everywhere a reaction is shown in the UI.
struct ReactionGlyph: View {
    let kind: ReactionKind
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(kind.tint)
    }
}

struct ReactionSummary: Codable {
    var counts: [String: Int]   // keyed by kind raw value
    var mine: String?           // kind raw value or nil

    static let empty = ReactionSummary(counts: [:], mine: nil)

    var myKind: ReactionKind? { mine.flatMap(ReactionKind.init(rawValue:)) }
}
