import SwiftUI

/// 目標タイムの Sub-X クイック設定。Web 版 marathon-record-app
/// `src/components/pace/GoalTimeSelector.tsx` の 2 段ネスト・ドロップダウン UX を SwiftUI 化。
///
/// 構造:
/// - 閉じた状態のトリガーボタン (現選択 Sub-X グループ + フォーマット時間 / 未選択時はプレースホルダ)
/// - 開いた状態: 直下に inline パネル
///   - パネル内の各 Sub-X グループ行をタップ → アコーディオンで内側にチップ展開
///   - チップタップ → `onSelect(seconds:)` 呼び出し → ドロップダウン全閉じ
/// - 同時に開けるグループは 1 つだけ
/// - レース種別変更時は閉じる
struct GoalTimeQuickSelect: View {
    let raceType: PaceRaceType
    let goalTimeSeconds: Int
    let onSelect: (Int) -> Void

    @State private var dropdownOpen: Bool = false
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
                Text("Goal Time — Quick Select")
                    .appText(.eyebrow)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    triggerButton
                    if dropdownOpen {
                        panel
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .onChange(of: raceType) { _, _ in
                expandedGroup = nil
                dropdownOpen = false
            }
            .animation(.easeInOut(duration: 0.18), value: dropdownOpen)
            .animation(.easeInOut(duration: 0.18), value: expandedGroup)
        }
    }

    // MARK: - Trigger button

    private var triggerButton: some View {
        Button {
            dropdownOpen.toggle()
            if !dropdownOpen { expandedGroup = nil }
        } label: {
            HStack {
                triggerLabel
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(dropdownOpen ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dropdownOpen ? Color.bgTertiary : Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        dropdownOpen ? Color.accentPrimary.opacity(0.5) : .white.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var triggerLabel: some View {
        if let active = activeGroup {
            HStack(spacing: 6) {
                Text(active.groupLabel)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.accentPrimary)
                Text("—")
                    .appText(.bodySm)
                    .foregroundStyle(.tertiary)
                Text(PaceUtils.formatTimeSimple(goalTimeSeconds))
                    .appText(.codeSm)
                    .foregroundStyle(Color.textPrimary)
            }
        } else {
            Text("Select target time…")
                .appText(.bodySm)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                groupRow(idx: idx, group: group)
                if idx < groups.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.04))
                        .frame(height: 0.5)
                }
            }
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.top, 6)
    }

    @ViewBuilder
    private func groupRow(idx: Int, group: SubTargetGroup) -> some View {
        let isExpanded = expandedGroup == idx
        let isActiveGroup = activeGroup?.groupLabel == group.groupLabel

        VStack(spacing: 0) {
            Button {
                expandedGroup = isExpanded ? nil : idx
            } label: {
                HStack {
                    Text(group.groupLabel)
                        .appText(.displaySm)
                        .foregroundStyle(isActiveGroup ? Color.accentPrimary : Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .background(isExpanded ? Color.bgTertiary : Color.clear)
            }
            .buttonStyle(.plain)

            if isExpanded {
                FlowLayout(spacing: 6) {
                    ForEach(group.items, id: \.seconds) { item in
                        SubTargetButton(
                            label: item.label,
                            isActive: goalTimeSeconds == item.seconds,
                            action: {
                                onSelect(item.seconds)
                                dropdownOpen = false
                                expandedGroup = nil
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background(Color.bgPrimary.opacity(0.6))
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
                .appText(isActive ? .codeXsBold : .codeXs)
                .foregroundStyle(isActive ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isActive ? Color.accentPrimary : Color.bgSecondary,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isActive ? .clear : .white.opacity(0.12),
                            lineWidth: 0.5
                        )
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
