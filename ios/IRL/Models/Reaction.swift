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

// MARK: - Branded glyph (hand-drawn SwiftUI faces)

/// Branded reaction icon used everywhere a reaction is shown in the UI.
/// Each kind is a hand-drawn SwiftUI shape — small expressive characters with
/// personality, in the kind's brand tint.
struct ReactionGlyph: View {
    let kind: ReactionKind
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch kind {
            case .smile: SmileGlyph(size: size)
            case .love:  LoveGlyph(size: size)
            case .wow:   WowGlyph(size: size)
            case .sad:   SadGlyph(size: size)
            case .laugh: LaughGlyph(size: size)
            case .fire:  FireGlyph(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Individual face glyphs

/// A round face base used by most kinds.
private struct FaceBase: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [tint, tint.opacity(0.85)],
                    center: UnitPoint(x: 0.35, y: 0.35),
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            .overlay(
                // Subtle inner highlight to give depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.35), .clear],
                            center: UnitPoint(x: 0.3, y: 0.25),
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
            )
    }
}

private struct SmileGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            FaceBase(size: size, tint: ReactionKind.smile.tint)
            // Two dot eyes
            HStack(spacing: size * 0.22) {
                Capsule().fill(.black.opacity(0.78)).frame(width: size * 0.08, height: size * 0.12)
                Capsule().fill(.black.opacity(0.78)).frame(width: size * 0.08, height: size * 0.12)
            }
            .offset(y: -size * 0.08)
            // Smile arc
            SmileArc()
                .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.06), lineCap: .round))
                .frame(width: size * 0.46, height: size * 0.26)
                .offset(y: size * 0.16)
        }
    }
}

private struct LaughGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            FaceBase(size: size, tint: ReactionKind.laugh.tint)
            // Squinty laughing eyes (^ ^)
            HStack(spacing: size * 0.22) {
                ArcEye().stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.07), lineCap: .round))
                    .frame(width: size * 0.16, height: size * 0.10)
                ArcEye().stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.07), lineCap: .round))
                    .frame(width: size * 0.16, height: size * 0.10)
            }
            .offset(y: -size * 0.08)
            // Big open laughing mouth (filled curve)
            OpenMouth()
                .fill(.black.opacity(0.78))
                .frame(width: size * 0.46, height: size * 0.28)
                .offset(y: size * 0.18)
        }
    }
}

private struct WowGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            FaceBase(size: size, tint: ReactionKind.wow.tint)
            // Big surprised eyes
            HStack(spacing: size * 0.20) {
                Circle().fill(.black.opacity(0.78)).frame(width: size * 0.14, height: size * 0.14)
                Circle().fill(.black.opacity(0.78)).frame(width: size * 0.14, height: size * 0.14)
            }
            .offset(y: -size * 0.06)
            // O mouth
            Circle()
                .stroke(.black.opacity(0.78), lineWidth: max(1.5, size * 0.06))
                .frame(width: size * 0.18, height: size * 0.22)
                .offset(y: size * 0.20)
        }
    }
}

private struct SadGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            FaceBase(size: size, tint: ReactionKind.sad.tint)
            // Closed eyes (slight downturn)
            HStack(spacing: size * 0.22) {
                ArcEye(downturn: true)
                    .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.07), lineCap: .round))
                    .frame(width: size * 0.14, height: size * 0.08)
                ArcEye(downturn: true)
                    .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.07), lineCap: .round))
                    .frame(width: size * 0.14, height: size * 0.08)
            }
            .offset(y: -size * 0.06)
            // Single tear
            TeardropShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.10, height: size * 0.16)
                .offset(x: -size * 0.16, y: size * 0.04)
            // Frown
            FrownArc()
                .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: max(1.5, size * 0.06), lineCap: .round))
                .frame(width: size * 0.40, height: size * 0.18)
                .offset(y: size * 0.22)
        }
    }
}

private struct LoveGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            HeartShape()
                .fill(
                    LinearGradient(
                        colors: [ReactionKind.love.tint, ReactionKind.love.tint.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    HeartShape()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.45), .clear],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: size * 0.35
                            )
                        )
                )
        }
        .frame(width: size, height: size)
    }
}

private struct FireGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [ReactionKind.fire.tint, Color(red: 1.0, green: 0.75, blue: 0.30)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            // Inner core
            FlameShape(coreScale: 0.55)
                .fill(Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.85))
                .scaleEffect(0.6, anchor: .bottom)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shape primitives

private struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height * 1.6)
        )
        return path
    }
}

private struct FrownArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: -rect.height * 0.6)
        )
        return path
    }
}

private struct ArcEye: Shape {
    var downturn: Bool = false
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if downturn {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: 0),
                control: CGPoint(x: rect.width / 2, y: rect.height * 1.6)
            )
        } else {
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height),
                control: CGPoint(x: rect.width / 2, y: -rect.height * 0.4)
            )
        }
        return path
    }
}

private struct OpenMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Top of mouth — straight-ish line
        path.move(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.05))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.05),
            control: CGPoint(x: rect.width / 2, y: rect.height * 0.15)
        )
        // Curve down to bottom
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.05),
            control: CGPoint(x: rect.width / 2, y: rect.height * 1.3)
        )
        path.closeSubpath()
        return path
    }
}

private struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Pointed top, rounded bottom
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.7),
            control: CGPoint(x: rect.width, y: rect.height * 0.35)
        )
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.height * 0.7),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: 0),
            control: CGPoint(x: 0, y: rect.height * 0.35)
        )
        path.closeSubpath()
        return path
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Start at the bottom point
        path.move(to: CGPoint(x: w / 2, y: h * 0.95))
        // Left side curves up to left lobe top
        path.addCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.32),
            control1: CGPoint(x: w * 0.10, y: h * 0.78),
            control2: CGPoint(x: w * 0.0, y: h * 0.55)
        )
        // Top of left lobe (arc)
        path.addArc(
            center: CGPoint(x: w * 0.27, y: h * 0.32),
            radius: w * 0.22,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Top of right lobe
        path.addArc(
            center: CGPoint(x: w * 0.73, y: h * 0.32),
            radius: w * 0.22,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Right side curves back down to bottom point
        path.addCurve(
            to: CGPoint(x: w / 2, y: h * 0.95),
            control1: CGPoint(x: w * 1.0, y: h * 0.55),
            control2: CGPoint(x: w * 0.90, y: h * 0.78)
        )
        path.closeSubpath()
        return path
    }
}

private struct FlameShape: Shape {
    var coreScale: CGFloat = 1.0
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Bottom-center
        path.move(to: CGPoint(x: w / 2, y: h * 0.98))
        // Right side up
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.55),
            control1: CGPoint(x: w * 0.95, y: h * 0.85),
            control2: CGPoint(x: w * 1.05, y: h * 0.7)
        )
        // Curve to right cusp
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.10),
            control1: CGPoint(x: w * 0.85, y: h * 0.30),
            control2: CGPoint(x: w * 0.78, y: h * 0.20)
        )
        // Inner notch (the flame's "tongue")
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.32),
            control: CGPoint(x: w * 0.47, y: h * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.40),
            control: CGPoint(x: w * 0.40, y: h * 0.45)
        )
        // Left cusp
        path.addCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.55),
            control1: CGPoint(x: w * 0.18, y: h * 0.30),
            control2: CGPoint(x: w * 0.10, y: h * 0.40)
        )
        // Left side back down to bottom
        path.addCurve(
            to: CGPoint(x: w / 2, y: h * 0.98),
            control1: CGPoint(x: w * -0.05, y: h * 0.7),
            control2: CGPoint(x: w * 0.05, y: h * 0.85)
        )
        path.closeSubpath()
        return path
    }
}
