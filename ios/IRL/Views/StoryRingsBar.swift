import SwiftUI

/// Horizontal bar of avatar rings for active stories. Renders above the feed.
struct StoryRingsBar: View {
    let groups: [StoryGroup]
    var onTapGroup: (StoryGroup) -> Void
    var onTapAddOwn: () -> Void

    private var ownGroup: StoryGroup? {
        guard let me = KeychainService.userId else { return nil }
        return groups.first { $0.authorId == me }
    }

    private var otherGroups: [StoryGroup] {
        let mine = ownGroup?.authorId
        return groups.filter { $0.authorId != mine }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ownEntry
                ForEach(otherGroups) { group in
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

    /// One entry that adapts: dashed "Your story" add tile when you have no
    /// active stories, or your own avatar ring with a `+` badge when you do.
    @ViewBuilder
    private var ownEntry: some View {
        if let own = ownGroup {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Button { onTapGroup(own) } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(IRLColors.earthGradient, lineWidth: 2.5)
                                .frame(width: 60, height: 60)
                            EarthView(autoRotate: false)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)

                    Button { onTapAddOwn() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(IRLColors.oceanBlue)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(IRLColors.deepSpace, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: 2)
                }
                .frame(width: 60, height: 60)

                Text("Your story")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 70)
        } else {
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
