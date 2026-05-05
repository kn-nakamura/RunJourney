import SwiftUI
import Charts

/// 生ペース vs 勾配補正ペース (GAP) を 2 系列で重ね描き。
/// 起伏のあるレースで体感ペースを把握するのに役立つ。
struct GAPOverlayChart: View {
    let trackPoints: [TrackPoint]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var points: [AdvancedAnalytics.GAPPoint] {
        AdvancedAnalytics.gradeAdjustedPace(trackPoints)
    }

    var body: some View {
        if points.count < 5 || trackPoints.contains(where: { $0.altitudeM != nil }) == false {
            Text("— need elevation data for GAP")
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
                    x: .value("Time (min)", p.timeSec / 60),
                    y: .value("Pace", p.paceSecPerKm),
                    series: .value("Series", "Pace")
                )
                .foregroundStyle(Color.accentPrimary.opacity(0.55))
                .lineStyle(.init(lineWidth: 1.4))
                LineMark(
                    x: .value("Time (min)", p.timeSec / 60),
                    y: .value("Pace", p.gapSecPerKm),
                    series: .value("Series", "GAP")
                )
                .foregroundStyle(Color.cat10K)
                .lineStyle(.init(lineWidth: 1.8))
            }
        }
        .chartForegroundStyleScale(
            domain: ["Pace", "GAP"],
            range: [Color.accentPrimary.opacity(0.55), Color.cat10K]
        )
        .chartLegend(position: .top, alignment: .leading)
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
