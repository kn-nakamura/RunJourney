import SwiftUI
import Charts

/// ラップごとのペース棒グラフ。Web版 LapChart.tsx 相当。
/// 平均より速いラップは緑、遅いラップは赤、近いラップはアクセント色で表示。
/// `targetPaceSecPerKm` を渡すと、目標ペースを破線の RuleMark で重ね描きする (Plan vs Actual)。
struct LapPaceChart: View {
    let laps: [LapData]
    var compact: Bool = false
    var targetPaceSecPerKm: Double? = nil

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var validLaps: [LapData] {
        laps.filter { $0.paceSecPerKm > 0 && $0.distanceM > 0 }
    }

    private var averagePace: Double? {
        guard !validLaps.isEmpty else { return nil }
        return validLaps.map(\.paceSecPerKm).reduce(0, +) / Double(validLaps.count)
    }

    var body: some View {
        if validLaps.isEmpty {
            Text("— no lap data")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            chart
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(validLaps, id: \.lapIndex) { lap in
                BarMark(
                    x: .value("Lap", lap.lapIndex),
                    y: .value("Pace (sec/km)", lap.paceSecPerKm)
                )
                .foregroundStyle(barColor(for: lap))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    if !compact {
                        Text(formatPace(lap.paceSecPerKm))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let avg = averagePace {
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .topTrailing, alignment: .trailing, spacing: 0) {
                        Text("Avg \(formatPace(avg))")
                            .appText(.codeXxs)
                            .foregroundStyle(.tertiary)
                    }
            }

            if let target = targetPaceSecPerKm, target > 0 {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Color.cat10K.opacity(0.85))
                    .lineStyle(.init(lineWidth: 1.5, dash: [2, 4]))
                    .annotation(position: .bottomTrailing, alignment: .trailing, spacing: 0) {
                        Text("Target \(formatPace(target))")
                            .appText(.codeXxs)
                            .foregroundStyle(Color.cat10K)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
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
            AxisMarks(values: .automatic(desiredCount: min(8, validLaps.count))) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: compact ? 120 : 200)
    }

    private func barColor(for lap: LapData) -> Color {
        guard let avg = averagePace else { return .accentPrimary }
        let deviation = (lap.paceSecPerKm - avg) / avg
        if deviation < -0.05 { return .cat10K }            // emerald-400 — faster
        if deviation > 0.05 { return .catFullMarathon }    // red-400 — slower
        return .accentPrimary                                // 蛍光イエロー
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d", m, s)
    }
}
