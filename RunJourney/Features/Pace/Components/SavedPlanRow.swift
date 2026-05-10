import SwiftUI

/// `PacePlan` 1 件を 1 行で表示するロウ。Pace Calculator の "Saved Plans" リスト用。
/// 距離・目標タイム・ペースをコンパクトに並べる。タップでロード、スワイプで削除。
struct SavedPlanRow: View {
    let plan: PacePlan
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(PaceUtils.formatDistance(km: plan.targetDistanceKm, in: unit)) · \(PaceUtils.formatTimeSimple(Int(plan.targetTimeSec)))")
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(PaceUtils.formatPace(secPerKm: Int(plan.paceSecPerKm), in: unit))
                .appText(.codeMd)
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
