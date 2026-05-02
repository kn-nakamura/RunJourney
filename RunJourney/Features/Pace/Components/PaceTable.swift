import SwiftUI

/// ペース計算機のラップ表 (DIST / PACE/KM / TIME / AVG/LAP の 4 列)。
/// Web 版 marathon-record-app `src/components/pace/PaceTable.tsx` の SwiftUI 移植。
///
/// 各行は ZStack で「ペース帯バー (背景, opacity 10%)」+「コンテンツ HStack」の 2 層。
/// バー幅と色は `PaceUtils.paceBarRatio` / `paceBarColor` で算出するので、
/// GPX エレベーション補正等で lap 別に pacePerKm が違うときにグラフが現れる。
/// 一定ペースの計算結果では全行のバーが同じ幅 (フラット) で表示される。
struct PaceTable: View {
    let laps: [PaceLapSegment]
    /// フッターに出すレース全体のラベル ("Full Marathon" 等)。
    let raceLabel: String

    private var minPace: Int { laps.map(\.pacePerKm).min() ?? 0 }
    private var maxPace: Int { laps.map(\.pacePerKm).max() ?? 0 }
    private var totalSeconds: Int {
        Int((laps.last?.cumulativeTime ?? 0).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                row(for: lap, index: index, isLast: index == laps.count - 1)
            }
            footer
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("DIST")
                .frame(width: 64, alignment: .leading)
            Text("PACE / KM")
                .frame(width: 92, alignment: .center)
            Text("TIME")
                .frame(width: 80, alignment: .center)
            Text("AVG / LAP")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .appText(.eyebrow)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for lap: PaceLapSegment, index: Int, isLast: Bool) -> some View {
        let isSpecial = lap.distanceLabel == "HALF" || lap.distanceLabel == "GOAL"
        let barColor = PaceUtils.paceBarColor(pace: lap.pacePerKm, minPace: minPace, maxPace: maxPace)
        let barRatio = PaceUtils.paceBarRatio(pace: lap.pacePerKm, minPace: minPace, maxPace: maxPace)
        let avgPace = PaceUtils.getAveragePace(laps: laps, upToIndex: index)

        ZStack(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .fill(barColor)
                    .frame(width: geo.size.width * barRatio)
                    .opacity(0.18)
            }
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                // DIST
                HStack(spacing: 4) {
                    Text(lap.distanceLabel)
                        .appText(isSpecial ? .codeSmBold : .codeSm)
                        .foregroundStyle(isSpecial ? Color.accentPrimary : Color.textPrimary)
                    if !isSpecial {
                        Text("km")
                            .appText(.codeXxs)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 64, alignment: .leading)

                // PACE/KM
                Text(PaceUtils.formatPaceSimple(lap.pacePerKm))
                    .appText(.codeSmBold)
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 92, alignment: .center)

                // TIME (cumulative)
                Text(PaceUtils.formatTimeSimple(Int(lap.cumulativeTime.rounded())))
                    .appText(isLast ? .codeBaseBold : .codeSm)
                    .foregroundStyle(isLast ? Color.accentPrimary : Color.textPrimary)
                    .frame(width: 80, alignment: .center)

                // AVG / LAP
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PaceUtils.formatPaceSimple(avgPace))
                        .appText(.codeXs)
                        .foregroundStyle(.secondary)
                    Text(PaceUtils.formatTimeSimple(Int(lap.lapTime.rounded())))
                        .appText(.codeXxs)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isLast ? Color.accentPrimary.opacity(0.5) : .white.opacity(0.04))
                .frame(height: isLast ? 1 : 0.5)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Spacer()
            Text(raceLabel)
                .appText(.eyebrow)
                .foregroundStyle(.secondary)
            Text("—")
                .appText(.codeXs)
                .foregroundStyle(.tertiary)
            Text(PaceUtils.formatTimeSimple(totalSeconds))
                .appText(.codeSmBold)
                .foregroundStyle(Color.accentPrimary)
            Spacer()
        }
        .padding(.vertical, 10)
    }
}
