import SwiftUI
import Charts

/// ケイデンス (歩/分) の時系列推移。データが無いときは自動非表示。
struct CadenceProfileChart: View {
    let trackPoints: [TrackPoint]

    private var validPoints: [TrackPoint] {
        trackPoints.filter { ($0.cadence ?? 0) > 0 }
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("— no cadence data")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(validPoints) { p in
            LineMark(
                x: .value("Time (min)", p.timeSec / 60),
                y: .value("Cadence (spm)", p.cadence ?? 0)
            )
            .foregroundStyle(Color.accentPrimary)
            .lineStyle(.init(lineWidth: 1.6))
            .interpolationMethod(.monotone)
        }
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
        .frame(height: 140)
    }
}
