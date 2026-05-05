import SwiftUI
import Charts

/// 複数結果の HR 推移を 1 枚に重ね描き。色は ComparisonView 共通パレットを使う。
struct HRProfileOverlayChart: View {
    let results: [RaceResult]
    let palette: [Color]

    private var validResults: [(idx: Int, result: RaceResult)] {
        results
            .filter { $0.trackPoints.contains(where: { ($0.heartRate ?? 0) > 0 }) }
            .enumerated()
            .map { (idx: $0.offset, result: $0.element) }
    }

    var body: some View {
        if validResults.count < 2 {
            Text("— need 2+ results with HR data")
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
                ForEach(item.result.trackPoints.filter { ($0.heartRate ?? 0) > 0 }) { p in
                    LineMark(
                        x: .value("Time (min)", p.timeSec / 60),
                        y: .value("HR", p.heartRate ?? 0),
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
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
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
}
