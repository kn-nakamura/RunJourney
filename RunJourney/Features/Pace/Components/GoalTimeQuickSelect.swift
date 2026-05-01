import SwiftUI

/// 目標タイムの Sub-X クイック設定 (Web 版 GoalTimeSelector.tsx の階層ドロップダウン相当)。
///
/// - グループ pill (Sub 4 等) を押すと中の候補時間が展開
/// - 候補タップで `onSelect(seconds:)` を呼ぶ
struct GoalTimeQuickSelect: View {
    let raceType: PaceRaceType
    let goalTimeSeconds: Int
    let onSelect: (Int) -> Void

    @State private var expandedGroup: Int? = nil

    private var groups: [SubTargetGroup] {
        SubTargetGroups.all[raceType] ?? []
    }

    private var activeGroup: SubTargetGroup? {
        groups.first(where: { g in g.items.contains(where: { $0.seconds == goalTimeSeconds }) })
    }

    var body: some View {
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("目標タイム — クイック設定")
                    .font(.body(10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)

                VStack(spacing: 6) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedGroup == idx },
                                set: { isExp in expandedGroup = isExp ? idx : nil }
                            )
                        ) {
                            FlowLayout(spacing: 6) {
                                ForEach(group.items, id: \.seconds) { item in
                                    SubTargetButton(
                                        label: item.label,
                                        isActive: goalTimeSeconds == item.seconds,
                                        action: { onSelect(item.seconds) }
                                    )
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        } label: {
                            HStack {
                                Text(group.groupLabel)
                                    .font(.body(13, weight: .bold))
                                    .foregroundStyle(activeGroup?.groupLabel == group.groupLabel ? Color.accentPrimary : Color.textPrimary)
                                Spacer()
                            }
                        }
                        .tint(Color.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .onChange(of: raceType) { _, _ in
                expandedGroup = nil
            }
        }
    }
}

// MARK: - SubTargetButton

private struct SubTargetButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.mono(12, bold: isActive))
                .foregroundStyle(isActive ? Color.black : Color.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isActive ? Color.accentPrimary : Color.bgPrimary,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? .clear : .white.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (chip 折り返し用)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if lineWidth + s.width > width {
                totalHeight += lineHeight + spacing
                maxLineWidth = max(maxLineWidth, lineWidth - spacing)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        totalHeight += lineHeight
        maxLineWidth = max(maxLineWidth, lineWidth - spacing)
        return CGSize(width: maxLineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if origin.x + s.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: origin, proposal: ProposedViewSize(s))
            origin.x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
