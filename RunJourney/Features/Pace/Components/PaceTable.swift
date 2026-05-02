import SwiftUI

/// ペース計算機のラップ表 (DIST / PACE/KM / TIME / AVG/LAP の 4 列)。
///
/// 各行は ZStack で「ペース帯バー (背景) + コンテンツ HStack」の 2 層。
/// バー長は `lap.pace / (basePace * 2)` を 0..1 でクランプ。
/// 例: basePace = 5:00 のとき、ペース 10:00 がちょうど右端 (1.0)、5:00 なら半分 (0.5)。
/// 色は basePace を境に lerp する: 速い側は emerald → teal、遅い側は teal → red。
/// 各バーは leading 濃 → trailing 薄の横グラデーションで描画。
struct PaceTable: View {
    let laps: [PaceLapSegment]
    /// フッターに出すレース全体のラベル ("Full Marathon" 等)。
    let raceLabel: String
    /// 基準ペース (秒/km)。バー長と色のしきい値。`PaceCalculatorView.pacePerKm` を渡す想定。
    let basePace: Int
    /// 行タップ時のコールバック。nil なら行は非インタラクティブ。
    var onTapLap: ((PaceLapSegment) -> Void)? = nil

    private var totalSeconds: Int {
        Int((laps.last?.cumulativeTime ?? 0).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                let rowView = row(for: lap, index: index, isLast: index == laps.count - 1)
                if let onTapLap {
                    Button { onTapLap(lap) } label: { rowView }
                        .buttonStyle(.plain)
                } else {
                    rowView
                }
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
        let avgPace = PaceUtils.getAveragePace(laps: laps, upToIndex: index)
        let ratio = PaceUtils.paceBarRatio(pace: lap.pacePerKm, basePace: basePace)
        let color = PaceUtils.paceBarColor(pace: lap.pacePerKm, basePace: basePace)

        ZStack(alignment: .leading) {
            // leading 濃 → trailing 薄のフェードグラデーションで pace 帯を可視化。
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.55),
                        color.opacity(0.10)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(2, geo.size.width * ratio), height: geo.size.height)
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
