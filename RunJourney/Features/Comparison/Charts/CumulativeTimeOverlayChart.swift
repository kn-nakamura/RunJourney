import SwiftUI
import Charts

/// 距離 vs 累積時間の重ね描き。同じ距離地点で誰が先行しているかを直感的に把握できる。
struct CumulativeTimeOverlayChart: View {
    let results: [RaceResult]
    let palette: [Color]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var validResults: [(idx: Int, result: RaceResult)] {
        results
            .filter { $0.trackPoints.count >= 2 }
            .enumerated()
            .map { (idx: $0.offset, result: $0.element) }
    }

    var body: some View {
        if validResults.count < 2 {
            Text("— need 2+ results with track points")
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
            ForEach(validResults, id: \.idx) { item in
                let label = dateLabel(item.result)
                let color = palette[item.idx % palette.count]
                ForEach(item.result.trackPoints) { p in
                    LineMark(
                        x: .value("Distance", (p.distanceM / 1000).displayed(in: unit)),
                        y: .value("Time", p.timeSec),
                        series: .value("Date", label)
                    )
                    .foregroundStyle(color)
                    .lineStyle(.init(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: validResults.map { dateLabel($0.result) },
            range: validResults.map { palette[$0.idx % palette.count] }
        )
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatDuration(raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f \(unit.label)", raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private func dateLabel(_ r: RaceResult) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM"
        return f.string(from: r.raceDate)
    }

    private func formatDuration(_ sec: Double) -> String {
        let s = Int(sec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%d:%02d", m, r)
    }
}
