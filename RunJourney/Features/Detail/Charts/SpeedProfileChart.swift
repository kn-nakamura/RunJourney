import SwiftUI
import Charts

/// 速度 (km/h or mph) の時系列推移。`TrackPoint.speedMs` から単位変換して表示。
struct SpeedProfileChart: View {
    let trackPoints: [TrackPoint]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var validPoints: [TrackPoint] {
        trackPoints.filter { ($0.speedMs ?? 0) > 0 }
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("— no speed data")
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
                y: .value("Speed", speedDisplay(p.speedMs ?? 0))
            )
            .foregroundStyle(Color.cat10K)
            .lineStyle(.init(lineWidth: 1.6))
            .interpolationMethod(.monotone)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f \(unit == .km ? "km/h" : "mph")", raw))
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
        .frame(height: 140)
    }

    private func speedDisplay(_ ms: Double) -> Double {
        let kmh = ms * 3.6
        return unit == .km ? kmh : kmh / kmPerMile
    }
}
