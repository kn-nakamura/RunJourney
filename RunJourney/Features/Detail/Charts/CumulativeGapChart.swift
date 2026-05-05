import SwiftUI
import Charts

/// Plan vs Actual の累積差 (秒) をラップ単位で折れ線表示する。
/// 0 ライン (= プラン通り) を破線で重ね、上に行くほどビハインド (slow)、下に行くほど貯金 (fast)。
struct CumulativeGapChart: View {
    let deltas: [AdvancedAnalytics.PlanLapDelta]

    var body: some View {
        if deltas.isEmpty {
            Text("— no laps to compare against plan")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            RuleMark(y: .value("On plan", 0))
                .foregroundStyle(.white.opacity(0.25))
                .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
            ForEach(deltas) { d in
                LineMark(
                    x: .value("Lap", d.lapIndex),
                    y: .value("Cumulative", d.cumulativeSec)
                )
                .foregroundStyle(Color.accentPrimary)
                .lineStyle(.init(lineWidth: 2))
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Lap", d.lapIndex),
                    y: .value("Cumulative", d.cumulativeSec)
                )
                .foregroundStyle(d.cumulativeSec >= 0 ? Color.catFullMarathon : Color.cat10K)
                .symbolSize(24)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(PaceUtils.formatSignedDuration(raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(8, deltas.count))) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: 170)
    }
}
