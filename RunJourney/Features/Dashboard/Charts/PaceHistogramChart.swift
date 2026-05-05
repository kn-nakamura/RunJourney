import SwiftUI
import Charts

/// カテゴリ単独モード時の平均ペース分布。距離が揃っているのでバケット幅 15 秒で描く。
struct PaceHistogramChart: View {
    /// (バケット開始秒/km, レース数)
    let buckets: [(bucketStart: Int, count: Int)]
    var bucketSec: Int = 15

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    var body: some View {
        if buckets.isEmpty {
            Text("Need finished races to chart pace")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(buckets, id: \.bucketStart) { item in
            BarMark(
                x: .value("Pace", paceLabel(item.bucketStart)),
                y: .value("Count", item.count)
            )
            .foregroundStyle(Color.accentPrimary.gradient)
            .cornerRadius(3)
            .annotation(position: .top) {
                Text("\(item.count)")
                    .appText(.codeXxsBold)
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.appFont(.codeXxs)) }
        }
        .frame(height: 150)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// バケット開始秒/km をユーザー単位に直して "M:SS" 表記。
    private func paceLabel(_ secPerKm: Int) -> String {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: secPerKm, in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d", m, s)
    }
}
