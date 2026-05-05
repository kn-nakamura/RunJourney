import SwiftUI
import Charts

/// カテゴリ別 PB 推移をマルチライン折れ線で重ね描き。
/// `data` が単一カテゴリのときも 1 本だけ綺麗に描けるよう `series` を貼っている。
struct PBProgressionChart: View {
    /// `RaceCategory` キーで PB が更新された点だけを受け取る。
    let data: [RaceCategory: [AdvancedAnalytics.PBPoint]]

    private var orderedCategories: [RaceCategory] {
        RaceCategory.allCases.filter { (data[$0]?.count ?? 0) >= 2 }
    }

    var body: some View {
        if orderedCategories.isEmpty {
            Text("Need 2+ PB updates to draw progression")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(orderedCategories) { cat in
                let points = data[cat] ?? []
                ForEach(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Time", p.finishSec),
                        series: .value("Category", cat.displayName)
                    )
                    .foregroundStyle(cat.pinColor)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(.stepEnd)
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Time", p.finishSec)
                    )
                    .foregroundStyle(cat.pinColor)
                    .symbolSize(28)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: orderedCategories.map(\.displayName),
            range: orderedCategories.map(\.pinColor)
        )
        .chartLegend(position: .bottom, alignment: .leading)
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
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel(format: .dateTime.year(.defaultDigits))
                    .font(.appFont(.codeXxs))
            }
        }
        .frame(height: 200)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
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
