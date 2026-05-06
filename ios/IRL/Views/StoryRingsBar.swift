import SwiftUI

/// Horizontal bar of avatar rings for active stories. Renders above the feed.
struct StoryRingsBar: View {
    let groups: [StoryGroup]
    var selfHasStory: Bool = false
    var onTapGroup: (StoryGroup) -> Void
    var onTapAddOwn: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                addOwnRing
                ForEach(groups) { group in
                    Button { onTapGroup(group) } label: {
                        ringFor(group)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var addOwnRing: some View {
        Button { onTapAddOwn() } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                        .frame(width: 60, height: 60)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text("Your story")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }

    private func ringFor(_ group: StoryGroup) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        group.hasUnseen ? AnyShapeStyle(IRLColors.earthGradient) : AnyShapeStyle(Color.white.opacity(0.2)),
                        lineWidth: group.hasUnseen ? 2.5 : 1.5
                    )
                    .frame(width: 60, height: 60)
                EarthView(autoRotate: false)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
            Text(group.authorName)
                .font(.system(size: 11, weight: group.hasUnseen ? .semibold : .medium, design: .rounded))
                .foregroundStyle(group.hasUnseen ? IRLColors.primaryText : IRLColors.primaryText.opacity(0.5))
                .lineLimit(1)
        }
        .frame(width: 70)
    }
}
