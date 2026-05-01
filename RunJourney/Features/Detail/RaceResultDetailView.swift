import SwiftUI
import SwiftData
import MapKit

/// 1つの結果(RaceResult)の詳細ビュー。
/// ヒーロータイム + 統計グリッド + ミニマップ + ラップチャート + 標高プロファイル + 心拍推移。
struct RaceResultDetailView: View {
    @Bindable var result: RaceResult
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                statsGrid
                routeMapSection
                lapChartSection
                elevationSection
                heartRateSection
                deleteSection
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle(result.race?.name ?? "結果")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.raceDate.formatted(date: .complete, time: .omitted))
                    .font(.body(13, weight: .medium))
                    .foregroundStyle(.secondary)
                if result.isPB {
                    Text("PB")
                        .font(.monoCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
                if result.isSB {
                    Text("SB")
                        .font(.monoCaption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.sbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(timeText)
                    .font(.displayHero)
                    .foregroundStyle(Color.accentPrimary)
                if let dnf = dnfLabel {
                    Text(dnf)
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            HStack(spacing: 14) {
                if let dist = result.summary?.totalDistanceM {
                    inlineMetric(value: String(format: "%.2f km", dist / 1000), label: "距離")
                }
                if let pace = result.summary?.avgPaceSecPerKm {
                    inlineMetric(value: formatPace(pace), label: "平均ペース")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var timeText: String {
        if let sec = result.finishTimeSec, sec > 0 { return formatDuration(sec) }
        return "—"
    }

    private var dnfLabel: String? {
        if result.isDNF { return "DNF" }
        if result.isDNS { return "DNS" }
        return nil
    }

    private func inlineMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.mono(15, bold: true)).foregroundStyle(Color.textPrimary)
            Text(label).font(.body(11)).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        let cells = makeStatCells()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cells.indices, id: \.self) { idx in
                cells[idx]
            }
        }
    }

    private func makeStatCells() -> [AnyView] {
        var arr: [AnyView] = []
        let s = result.summary

        if let hr = s?.avgHeartRate {
            arr.append(AnyView(StatCell(label: "平均HR", value: "\(hr)", unit: "bpm", symbol: "heart.fill", color: .catFullMarathon)))
        }
        if let hr = s?.maxHeartRate {
            arr.append(AnyView(StatCell(label: "最大HR", value: "\(hr)", unit: "bpm", symbol: "heart.circle.fill", color: .catFullMarathon)))
        }
        if let elev = s?.elevationGainM {
            arr.append(AnyView(StatCell(label: "上昇", value: String(format: "%.0f", elev), unit: "m", symbol: "arrow.up.right.circle.fill", color: .cat10K)))
        }
        if let elev = s?.elevationLossM {
            arr.append(AnyView(StatCell(label: "下降", value: String(format: "%.0f", elev), unit: "m", symbol: "arrow.down.right.circle.fill", color: .cat5K)))
        }
        if let cad = s?.avgCadence {
            arr.append(AnyView(StatCell(label: "平均ケイデンス", value: "\(cad)", unit: "spm", symbol: "figure.run", color: .accentPrimary)))
        }
        if let pow = s?.avgPowerW {
            arr.append(AnyView(StatCell(label: "平均パワー", value: String(format: "%.0f", pow), unit: "W", symbol: "bolt.fill", color: .catHalfMarathon)))
        }
        if let cal = s?.totalCalories {
            arr.append(AnyView(StatCell(label: "カロリー", value: String(format: "%.0f", cal), unit: "kcal", symbol: "flame.fill", color: .catUltra100K)))
        }
        if let temp = s?.avgTemperatureC {
            arr.append(AnyView(StatCell(label: "気温", value: String(format: "%.1f", temp), unit: "°C", symbol: "thermometer", color: .cat5K)))
        }
        return arr
    }

    // MARK: - Map

    private var routeMapSection: some View {
        let coords = result.trackPoints.map(\.coordinate)
        return Group {
            if coords.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionHeader("ルート")
                        Spacer()
                        NavigationLink {
                            RouteFlythruView(result: result)
                        } label: {
                            Label("再生", systemImage: "play.circle.fill")
                                .font(.body(13, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentPrimary, in: Capsule())
                        }
                    }
                    Map {
                        MapPolyline(coordinates: coords)
                            .stroke(
                                result.race?.category.pinColor ?? .accentPrimary,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                        if let first = coords.first {
                            Annotation("Start", coordinate: first) {
                                Image(systemName: "flag.checkered")
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Color.cat10K, in: Circle())
                            }
                        }
                        if let last = coords.last, coords.count > 1 {
                            Annotation("Finish", coordinate: last) {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Color.catFullMarathon, in: Circle())
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Charts

    private var lapChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ラップ別ペース", subtitle: result.lapData.isEmpty ? nil : "\(result.lapData.count) ラップ")
            LapPaceChart(laps: result.lapData)
        }
    }

    private var elevationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("標高プロファイル")
            ElevationProfileChart(trackPoints: result.trackPoints)
        }
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("心拍推移")
            HeartRateChart(trackPoints: result.trackPoints)
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            modelContext.delete(result)
            try? modelContext.save()
            dismiss()
        } label: {
            Label("この結果を削除", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body(15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(.body(12))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }
}

// MARK: - Supporting views

private struct StatCell: View {
    let label: String
    let value: String
    let unit: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body(11))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.mono(17, bold: true))
                        .foregroundStyle(Color.textPrimary)
                    Text(unit)
                        .font(.body(10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
