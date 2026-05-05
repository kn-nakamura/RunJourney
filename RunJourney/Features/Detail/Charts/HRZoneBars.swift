import SwiftUI
import Charts

/// HR ゾーン (Z1〜Z5) ごとの滞在時間を割合として可視化する積み上げバー。
/// `userMaxHR == 0` のときは Settings 誘導テキストを表示。
struct HRZoneBars: View {
    let trackPoints: [TrackPoint]

    @AppStorage("userMaxHR") private var userMaxHR: Int = 0

    private var distribution: [AdvancedAnalytics.HRZone: Double] {
        AdvancedAnalytics.hrZoneDistribution(trackPoints, maxHR: userMaxHR)
    }

    private var totalSec: Double {
        distribution.values.reduce(0, +)
    }

    var body: some View {
        if userMaxHR <= 0 {
            Text("Set Max HR in Settings to enable HR Zone analysis.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else if totalSec <= 0 {
            Text("— no heart rate data")
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
            ForEach(AdvancedAnalytics.HRZone.allCases) { zone in
                let sec = distribution[zone] ?? 0
                BarMark(
                    x: .value("Time (sec)", sec),
                    y: .value("Zone", zone.label)
                )
                .foregroundStyle(zoneColor(zone))
                .annotation(position: .trailing) {
                    if sec > 0 {
                        Text(percentText(sec))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().font(.appFont(.codeXs))
            }
        }
        .frame(height: CGFloat(AdvancedAnalytics.HRZone.allCases.count) * 28)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AdvancedAnalytics.HRZone.allCases) { zone in
                HStack(spacing: 6) {
                    Circle().fill(zoneColor(zone)).frame(width: 8, height: 8)
                    Text("\(zone.label) · \(zone.description)")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(durationText(distribution[zone] ?? 0))
                        .appText(.codeXxs)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func zoneColor(_ zone: AdvancedAnalytics.HRZone) -> Color {
        switch zone {
        case .z1: return .cat5K
        case .z2: return .cat10K
        case .z3: return .accentPrimary
        case .z4: return .catHalfMarathon
        case .z5: return .catFullMarathon
        }
    }

    private func percentText(_ sec: Double) -> String {
        guard totalSec > 0 else { return "" }
        let pct = sec / totalSec * 100
        return String(format: "%.0f%%", pct)
    }

    private func durationText(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
