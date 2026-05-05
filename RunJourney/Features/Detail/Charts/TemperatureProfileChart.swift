import SwiftUI
import Charts

/// 気温 (℃) の時系列推移。FIT/TCX が温度を取得しているレースで描画。
struct TemperatureProfileChart: View {
    let trackPoints: [TrackPoint]

    private var validPoints: [TrackPoint] {
        trackPoints.filter { $0.temperatureC != nil }
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("— no temperature data")
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
                y: .value("Temp (°C)", p.temperatureC ?? 0)
            )
            .foregroundStyle(Color.cat5K)
            .lineStyle(.init(lineWidth: 1.5))
            .interpolationMethod(.monotone)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f°C", raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: 130)
    }
}
