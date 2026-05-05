import SwiftUI
import Charts

/// 年×カテゴリの距離 (km) 積み上げ棒グラフ。Dashboard "All" モード用。
/// `RaceCategory.pinColor` でカテゴリ色を維持し、視覚的に Races by Category と整合させる。
struct DistancePerYearChart: View {
    let data: [AdvancedAnalytics.YearDistance]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        if data.isEmpty {
            Text("No yearly distance data")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Year", "\(item.year)"),
                y: .value("Distance", item.distanceKm.displayed(in: unit))
            )
            .foregroundStyle(by: .value("Category", item.category.displayName))
            .cornerRadius(2)
        }
        .chartForegroundStyleScale(
            domain: RaceCategory.allCases.map(\.displayName),
            range: RaceCategory.allCases.map(\.pinColor)
        )
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(raw)) \(unit.label)")
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.appFont(.codeXxs)) }
        }
        .frame(height: 180)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
