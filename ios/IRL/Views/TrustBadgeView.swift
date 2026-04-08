import SwiftUI

struct TrustBadgeView: View {
    let level: TrustLevel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: level.icon)
                .font(.system(size: 10))
            Text(level.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch level {
        case .verified: return IRLColors.earthGreen
        case .cameraRoll: return IRLColors.oceanBlue
        case .unverified: return .orange
        }
    }
}
