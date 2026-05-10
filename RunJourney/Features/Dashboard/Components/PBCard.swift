import SwiftUI

/// カテゴリ別 Personal Best 1 件分の表示。Dashboard の PB Board でグリッド配置される。
/// 右肩に "PB" バッジと finish time、左にカテゴリ symbol。
struct PBCard: View {
    let category: RaceCategory
    let result: RaceResult

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.pinColor.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: category.symbolName)
                    .foregroundStyle(category.pinColor)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Text(result.race?.name ?? "—")
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(PaceUtils.formatDuration(result.finishTimeSec ?? 0))
                    .appText(.codeLg)
                    .foregroundStyle(Color.accentPrimary)
                Text("PB")
                    .appText(.badgeNumeric)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.pbBadge, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
