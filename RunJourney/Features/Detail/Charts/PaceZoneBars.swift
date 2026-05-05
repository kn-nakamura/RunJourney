import SwiftUI
import Charts

/// 目標ペース ± 許容差で Fast / Target / Slow に分類した時間配分。
/// 紐付いた PacePlan があるときだけ表示する想定。
struct PaceZoneBars: View {
    let laps: [LapData]
    let targetPaceSecPerKm: Double
    var toleranceSec: Int = 10

    private var distribution: [AdvancedAnalytics.PaceBucket: Double] {
        AdvancedAnalytics.paceZoneDistribution(
            laps: laps,
            targetSecPerKm: targetPaceSecPerKm,
            toleranceSec: toleranceSec
        )
    }

    private var total: Double {
        distribution.values.reduce(0, +)
    }

    var body: some View {
        if total <= 0 || targetPaceSecPerKm <= 0 {
            Text("— no laps to evaluate against target")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
            legend
        }
    }

    private var chart: some View {
        Chart {
            ForEach(AdvancedAnalytics.PaceBucket.allCases) { bucket in
                let sec = distribution[bucket] ?? 0
                BarMark(
                    x: .value("Time (sec)", sec),
                    y: .value("Bucket", bucket.label)
                )
                .foregroundStyle(color(bucket))
                .annotation(position: .trailing) {
                    if sec > 0 {
                        Text(percentText(sec))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.appFont(.codeXs))
            }
        }
        .frame(height: CGFloat(AdvancedAnalytics.PaceBucket.allCases.count) * 30)
    }

    private var legend: some View {
        Text("Target ±\(toleranceSec)s/km from \(formatPace(targetPaceSecPerKm))")
            .appText(.bodyXs)
            .foregroundStyle(.tertiary)
    }

    private func color(_ bucket: AdvancedAnalytics.PaceBucket) -> Color {
        switch bucket {
        case .fast:   return .cat10K
        case .target: return .accentPrimary
        case .slow:   return .catFullMarathon
        }
    }

    private func percentText(_ sec: Double) -> String {
        guard total > 0 else { return "" }
        return String(format: "%.0f%%", sec / total * 100)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let s = Int(secPerKm.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
