import SwiftUI
import Charts

/// 標高プロファイル（距離 vs 標高、AreaMark）。
struct ElevationProfileChart: View {
    let trackPoints: [TrackPoint]

    private var validPoints: [TrackPoint] {
        trackPoints.filter { $0.altitudeM != nil }
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("— no elevation data")
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
            AreaMark(
                x: .value("Distance (km)", p.distanceM / 1000),
                y: .value("Elevation (m)", p.altitudeM ?? 0)
            )
            .foregroundStyle(.linearGradient(
                colors: [Color.cat10K.opacity(0.7), Color.cat10K.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Distance (km)", p.distanceM / 1000),
                y: .value("Elevation (m)", p.altitudeM ?? 0)
            )
            .foregroundStyle(Color.cat10K)
            .lineStyle(.init(lineWidth: 1.5))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f m", raw))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 140)
    }
}

/// 心拍推移（時間 vs HR、LineMark）。
struct HeartRateChart: View {
    let trackPoints: [TrackPoint]

    private var validPoints: [TrackPoint] {
        trackPoints.filter { ($0.heartRate ?? 0) > 0 }
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("— no heart rate data")
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
                y: .value("HR (bpm)", p.heartRate ?? 0)
            )
            .foregroundStyle(Color.catFullMarathon)
            .lineStyle(.init(lineWidth: 1.8))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: 140)
    }
}

/// 複数結果のラップペース重ね合わせ（年別比較）。
struct MultiResultLapPaceChart: View {
    /// 比較対象の結果。最大4件まで色分けして表示する。
    let results: [RaceResult]

    private var validResults: [(idx: Int, result: RaceResult)] {
        results
            .filter { !$0.lapData.isEmpty }
            .enumerated()
            .map { (idx: $0.offset, result: $0.element) }
    }

    private static let palette: [Color] = [
        .accentPrimary,           // 黄緑 (最新)
        .cat10K,                  // 緑
        .cat5K,                   // 青
        .catTrail,                // 紫
        .catUltra100K,            // オレンジ
    ]

    var body: some View {
        if validResults.count < 2 {
            Text("— need 2+ results with lap data to compare")
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
                let label = yearLabel(for: item.result)
                let color = Self.palette[item.idx % Self.palette.count]
                ForEach(item.result.lapData.filter { $0.paceSecPerKm > 0 }, id: \.lapIndex) { lap in
                    LineMark(
                        x: .value("Lap", lap.lapIndex),
                        y: .value("Pace", lap.paceSecPerKm),
                        series: .value("Year", label)
                    )
                    .foregroundStyle(color)
                    .lineStyle(.init(lineWidth: 2))
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Lap", lap.lapIndex),
                        y: .value("Pace", lap.paceSecPerKm)
                    )
                    .foregroundStyle(color)
                    .symbolSize(20)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: validResults.map { yearLabel(for: $0.result) },
            range: validResults.map { Self.palette[$0.idx % Self.palette.count] }
        )
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(PaceUtils.formatPaceSimple(Int(raw)))
                            .appText(.codeXxs)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().font(.appFont(.codeXxs))
            }
        }
        .frame(height: 220)
    }

    private func yearLabel(for result: RaceResult) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy"
        return f.string(from: result.raceDate)
    }

}

/// 複数結果のフィニッシュタイム比較棒グラフ。
struct FinishTimeComparisonChart: View {
    let results: [RaceResult]

    private var validResults: [RaceResult] {
        results
            .filter { !$0.isDNF && !$0.isDNS && ($0.finishTimeSec ?? 0) > 0 }
            .sorted { $0.raceDate < $1.raceDate }
    }

    private var pbSec: Double? {
        validResults.compactMap(\.finishTimeSec).min()
    }

    var body: some View {
        if validResults.count < 2 {
            EmptyView()
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(validResults, id: \.id) { result in
                let label = dateLabel(result)
                let isPB = result.finishTimeSec == pbSec
                BarMark(
                    x: .value("Date", label),
                    y: .value("Time", result.finishTimeSec ?? 0)
                )
                .foregroundStyle(isPB ? Color.accentPrimary : Color.bgTertiary.opacity(0.85))
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(PaceUtils.formatDuration(result.finishTimeSec ?? 0))
                        .appText(isPB ? .codeXxsBold : .codeXxs)
                        .foregroundStyle(isPB ? Color.accentPrimary : .secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                if let raw = value.as(Double.self) {
                    AxisValueLabel {
                        Text(PaceUtils.formatDuration(raw))
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
    }

    private func dateLabel(_ result: RaceResult) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: result.raceDate)
    }

}
