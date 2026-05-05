import SwiftUI

/// Lap ごとの距離・時間・ペース・心拍・標高+/− を行表示する一覧。
/// 右側に平均ペースからの偏差を細い水平バーで描く (`paceBarColor` / `paceBarRatio` を流用)。
struct SplitsTable: View {
    let laps: [LapData]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var validLaps: [LapData] {
        laps.filter { $0.paceSecPerKm > 0 && $0.distanceM > 0 }
    }

    private var averagePaceSec: Int {
        guard !validLaps.isEmpty else { return 0 }
        let avg = validLaps.map(\.paceSecPerKm).reduce(0, +) / Double(validLaps.count)
        return Int(avg.rounded())
    }

    var body: some View {
        if validLaps.isEmpty {
            Text("— no lap data")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.leading, 12)
            ForEach(Array(validLaps.enumerated()), id: \.element.id) { idx, lap in
                row(lap)
                if idx < validLaps.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Lap")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .leading)
            Text("Dist")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(width: 56, alignment: .trailing)
            Text("Time")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .trailing)
            Text("Pace")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(width: 56, alignment: .trailing)
            Spacer(minLength: 8)
            Text("vs Avg")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(_ lap: LapData) -> some View {
        let paceInt = Int(lap.paceSecPerKm.rounded())
        let displayedPace = PaceUtils.paceSecondsPerUnit(secPerKm: paceInt, in: unit)
        let delta = paceInt - averagePaceSec
        let kmDist = lap.distanceM / 1000

        return HStack(spacing: 10) {
            Text("\(lap.lapIndex)")
                .appText(.codeBaseBold)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 38, alignment: .leading)
            Text(PaceUtils.formatDistanceValue(km: kmDist, in: unit))
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(formatLapTime(lap.timeSec))
                .appText(.codeXs)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            Text(formatPaceShort(displayedPace))
                .appText(.codeBaseBold)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 56, alignment: .trailing)

            // delta bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.bgTertiary.opacity(0.45))
                        .frame(height: 6)
                    Capsule()
                        .fill(PaceUtils.paceBarColor(pace: paceInt, basePace: averagePaceSec))
                        .frame(
                            width: geo.size.width * CGFloat(PaceUtils.paceBarRatio(pace: paceInt, basePace: averagePaceSec)),
                            height: 6
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 6)

            Text(PaceUtils.formatSignedDuration(Double(delta)))
                .appText(.codeXxs)
                .foregroundStyle(deltaColor(delta))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta < -2 { return .cat10K }
        if delta > 2 { return .catFullMarathon }
        return .secondary
    }

    private func formatLapTime(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let m = s / 60
        let r = s % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, r)
        }
        return String(format: "%d:%02d", m, r)
    }

    private func formatPaceShort(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
