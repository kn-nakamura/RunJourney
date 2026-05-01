import SwiftUI
import Charts

/// ラップごとのペース棒グラフ。Web版 LapChart.tsx 相当。
/// 平均より速いラップは緑、遅いラップは赤、近いラップはアクセント色で表示。
struct LapPaceChart: View {
    let laps: [LapData]
    var compact: Bool = false

    private var validLaps: [LapData] {
        laps.filter { $0.paceSecPerKm > 0 && $0.distanceM > 0 }
    }

    private var averagePace: Double? {
        guard !validLaps.isEmpty else { return nil }
        return validLaps.map(\.paceSecPerKm).reduce(0, +) / Double(validLaps.count)
    }

    var body: some View {
        if validLaps.isEmpty {
            ContentUnavailableView(
                "ラップデータなし",
                systemImage: "list.dash",
                description: Text("ファイルに区切りデータが含まれていません")
            )
            .frame(height: compact ? 100 : 140)
        } else {
            chart
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(validLaps, id: \.lapIndex) { lap in
                BarMark(
                    x: .value("ラップ", lap.lapIndex),
                    y: .value("ペース (秒/km)", lap.paceSecPerKm)
                )
                .foregroundStyle(barColor(for: lap))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    if !compact {
                        Text(formatPace(lap.paceSecPerKm))
                            .font(.mono(9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let avg = averagePace {
                RuleMark(y: .value("平均", avg))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .topTrailing, alignment: .trailing, spacing: 0) {
                        Text("平均 \(formatPace(avg))")
                            .font(.mono(9))
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatPace(raw))
                            .font(.mono(10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(8, validLaps.count))) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel().font(.mono(10))
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
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }
}
