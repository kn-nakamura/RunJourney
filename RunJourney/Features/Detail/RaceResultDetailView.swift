import SwiftUI
import SwiftData
import MapKit

/// 1つの結果(RaceResult)の詳細ビュー。
/// ヒーロータイム + 統計グリッド + ミニマップ + ラップチャート + 標高プロファイル + 心拍推移。
struct RaceResultDetailView: View {
    @Bindable var result: RaceResult
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    @State private var showDeleteSheet = false
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                weatherSummary
                statsGrid
                routeMapSection
                lapChartSection
                elevationSection
                heartRateSection
                ResultMemoriesCard(result: result)
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle(result.race?.name ?? "Result")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteSheet = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Delete Result")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.accentPrimary)
                }
                .accessibilityLabel("Share Result")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RaceResultEditView(result: result)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ResultShareSheet(result: result)
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteConfirmSheet(
                title: "Delete Result",
                message: "This will permanently delete this result, including laps and route.",
                confirmLabel: "Confirm Deletion",
                finalAlertTitle: "Delete this result?",
                finalAlertMessage: "This cannot be undone.",
                onDelete: {
                    AttachmentStore.deleteAll(ownerID: result.id)
                    modelContext.delete(result)
                    try? modelContext.save()
                    dismiss()
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Weather summary (read-only)

    @ViewBuilder
    private var weatherSummary: some View {
        if result.weatherTempC != nil || result.weatherDescription != nil || result.condition != nil {
            HStack(spacing: 16) {
                if let desc = result.weatherDescription {
                    HStack(spacing: 6) {
                        Image(systemName: desc.symbolName)
                            .foregroundStyle(Color.accentPrimary)
                        Text(desc.displayName)
                            .appText(.bodySmBold)
                    }
                }
                if let temp = result.weatherTempC {
                    Text(String(format: "%.1f°C", temp))
                        .appText(.codeMd)
                }
                if let cond = result.condition {
                    HStack(spacing: 4) {
                        Image(systemName: cond.symbolName)
                            .foregroundStyle(.secondary)
                        Text(cond.displayName).appText(.bodyXs)
                    }
                }
                Spacer()
            }
            .foregroundStyle(Color.textPrimary)
            .padding(12)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.raceDate.formatted(date: .complete, time: .omitted))
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
                if result.isPB {
                    Text("PB")
                        .appText(.badgeNumeric)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
                if result.isSB {
                    Text("SB")
                        .appText(.badgeNumeric)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.sbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(timeText)
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
                if let dnf = dnfLabel {
                    Text(dnf)
                        .appText(.bodySmBold)
                        .foregroundStyle(.red)
                }
            }
            HStack(spacing: 14) {
                if let dist = result.summary?.totalDistanceM {
                    inlineMetric(value: PaceUtils.formatDistance(km: dist / 1000, in: unit), label: "Distance")
                }
                if let pace = result.summary?.avgPaceSecPerKm {
                    inlineMetric(value: formatPace(pace), label: "Avg Pace")
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
            Text(value).appText(.codeBaseBold).foregroundStyle(Color.textPrimary)
            Text(label).appText(.bodyXs).foregroundStyle(.tertiary)
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
            arr.append(AnyView(StatCell(label: "Avg HR", value: "\(hr)", unit: "bpm", symbol: "heart.fill", color: .catFullMarathon)))
        }
        if let hr = s?.maxHeartRate {
            arr.append(AnyView(StatCell(label: "Max HR", value: "\(hr)", unit: "bpm", symbol: "heart.circle.fill", color: .catFullMarathon)))
        }
        if let elev = s?.elevationGainM {
            arr.append(AnyView(StatCell(label: "Ascent", value: String(format: "%.0f", elev), unit: "m", symbol: "arrow.up.right.circle.fill", color: .cat10K)))
        }
        if let elev = s?.elevationLossM {
            arr.append(AnyView(StatCell(label: "Descent", value: String(format: "%.0f", elev), unit: "m", symbol: "arrow.down.right.circle.fill", color: .cat5K)))
        }
        if let cad = s?.avgCadence {
            arr.append(AnyView(StatCell(label: "Avg Cadence", value: "\(cad)", unit: "spm", symbol: "figure.run", color: .accentPrimary)))
        }
        if let pow = s?.avgPowerW {
            arr.append(AnyView(StatCell(label: "Avg Power", value: String(format: "%.0f", pow), unit: "W", symbol: "bolt.fill", color: .catHalfMarathon)))
        }
        if let cal = s?.totalCalories {
            arr.append(AnyView(StatCell(label: "Calories", value: String(format: "%.0f", cal), unit: "kcal", symbol: "flame.fill", color: .catUltra100K)))
        }
        if let temp = s?.avgTemperatureC {
            arr.append(AnyView(StatCell(label: "Temp", value: String(format: "%.1f", temp), unit: "°C", symbol: "thermometer", color: .cat5K)))
        }
        return arr
    }

    // MARK: - Map

    private var routeMapSection: some View {
        let coords = result.trackPoints.map(\.coordinate)
        return Group {
            if coords.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Route", subtitle: "Tap to play flythrough")
                    NavigationLink {
                        RouteFlythruView(result: result)
                    } label: {
                        ZStack(alignment: .topTrailing) {
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

                            // 右上に控えめな再生インジケータ
                            Image(systemName: "play.fill")
                                .foregroundStyle(.black)
                                .padding(10)
                                .background(Color.accentPrimary, in: Circle())
                                .shadow(radius: 3)
                                .padding(10)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Charts

    private var lapChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Lap Pace", subtitle: result.lapData.isEmpty ? nil : "\(result.lapData.count) laps")
            LapPaceChart(laps: result.lapData)
        }
    }

    private var elevationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Elevation Profile")
            ElevationProfileChart(trackPoints: result.trackPoints)
        }
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Heart Rate")
            HeartRateChart(trackPoints: result.trackPoints)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d \(unit.perLabel)", m, s)
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
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .appText(.codeMdBold)
                        .foregroundStyle(Color.textPrimary)
                    Text(unit)
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
