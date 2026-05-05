import SwiftUI
import Charts

/// 1km ごとに区切ったローリングペースの折れ線。距離 vs ペース (秒/km)。
/// `targetPaceSecPerKm` を渡すと target line を破線で描く。
struct PaceProfileChart: View {
    let trackPoints: [TrackPoint]
    var targetPaceSecPerKm: Double? = nil

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var points: [AdvancedAnalytics.RollingPacePoint] {
        AdvancedAnalytics.rollingKmPace(trackPoints)
    }

    var body: some View {
        if points.isEmpty {
            Text("— need 1+ km to compute rolling pace")
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
            ForEach(points) { p in
                LineMark(
                    x: .value("Distance (km)", p.km),
                    y: .value("Pace", p.paceSecPerKm)
                )
                .foregroundStyle(Color.accentPrimary)
                .lineStyle(.init(lineWidth: 2))
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Distance (km)", p.km),
                    y: .value("Pace", p.paceSecPerKm)
                )
                .foregroundStyle(Color.accentPrimary)
                .symbolSize(18)
            }
            if let target = targetPaceSecPerKm, target > 0 {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Color.cat10K.opacity(0.85))
                    .lineStyle(.init(lineWidth: 1.2, dash: [2, 4]))
                    .annotation(position: .bottomTrailing) {
                        Text("Target \(formatPace(target))")
                            .appText(.codeXxs)
                            .foregroundStyle(Color.cat10K)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatPace(raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: 160)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d", m, s)
    }
}
