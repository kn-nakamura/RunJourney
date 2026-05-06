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
    @AppStorage("userMaxHR") private var userMaxHR: Int = 0
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    @Query private var allPlans: [PacePlan]

    @State private var showDeleteSheet = false
    @State private var showShareSheet = false
    @State private var showAIReviewSheet = false
    /// iPad / Mac でフライスルーを画面いっぱいに表示するための fullScreenCover フラグ。
    /// iPhone では NavigationLink で push する従来挙動を維持する (swipe-back を残すため)。
    @State private var showFullscreenFlythrough = false

    /// `ContentView` が `\.adaptiveLayout` 経由で流す端末プロファイル。
    /// iPad では NavigationStack の detail 列に push すると sidebar に挟まれて狭く
    /// 見えるので、フライスルーだけは fullScreenCover で全画面に乗せ替える。
    @Environment(\.adaptiveLayout) private var layout

    private var linkedPlan: PacePlan? {
        guard let id = result.linkedPacePlanId else { return nil }
        return allPlans.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            // ViewBuilder の child 上限 (10) を超えないよう、論理ブロックごとに Group でまとめる。
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    heroSection
                    weatherSummary
                    statsGrid
                    routeMapSection
                }
                Group {
                    splitsSection
                    lapChartSection
                    paceProfileSection
                    halfSplitSection
                }
                Group {
                    hrZoneSection
                    paceZoneSection
                }
                Group {
                    heartRateSection
                    cadenceSection
                    powerSection
                    speedSection
                    temperatureSection
                }
                Group {
                    elevationSection
                    gapSection
                    planVsActualSection
                }
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
                Button {
                    showAIReviewSheet = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.accentPrimary)
                }
                .accessibilityLabel("AI Review")
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
        // iPad / Mac 専用: フライスルーを画面いっぱいに乗せる。
        // RouteFlythruView 内の `dismiss()` (chevron.left ボタン) でそのまま閉じられる。
        .fullScreenCover(isPresented: $showFullscreenFlythrough) {
            RouteFlythruView(result: result)
        }
        .sheet(isPresented: $showAIReviewSheet) {
            AIReviewSheet(result: result, race: result.race, plan: linkedPlan)
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
                    // iPad は NavigationSplitView の detail 列内に push するとサイドバーに
                    // 挟まれて狭くなるので、Button + fullScreenCover で全画面に乗せ替える。
                    // iPhone はそもそも全幅なので NavigationLink の push (swipe-back あり)
                    // を維持する方が UX 的に自然。
                    if layout.usesSidebarRoot {
                        Button {
                            showFullscreenFlythrough = true
                        } label: {
                            routeMapPreview(coords: coords)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            RouteFlythruView(result: result)
                        } label: {
                            routeMapPreview(coords: coords)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// ルートマップのプレビュー (タップ前の状態)。タップ操作は呼び出し側で包む。
    @ViewBuilder
    private func routeMapPreview(coords: [CLLocationCoordinate2D]) -> some View {
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

    // MARK: - Charts

    private var lapChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Lap Pace",
                subtitle: lapChartSubtitle
            )
            LapPaceChart(laps: result.lapData, targetPaceSecPerKm: linkedPlan?.paceSecPerKm)
        }
    }

    private var lapChartSubtitle: String? {
        if result.lapData.isEmpty { return nil }
        if let plan = linkedPlan {
            let name = plan.name.isEmpty ? "plan" : plan.name
            return "\(result.lapData.count) laps · target \(name)"
        }
        return "\(result.lapData.count) laps"
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

    // MARK: - Splits

    @ViewBuilder
    private var splitsSection: some View {
        if !result.lapData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Splits", subtitle: "\(result.lapData.count) laps")
                SplitsTable(laps: result.lapData)
            }
        }
    }

    // MARK: - Pace profile (rolling 1km)

    @ViewBuilder
    private var paceProfileSection: some View {
        if result.trackPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Pace Profile", subtitle: "rolling per km")
                PaceProfileChart(
                    trackPoints: result.trackPoints,
                    targetPaceSecPerKm: linkedPlan?.paceSecPerKm
                )
            }
        }
    }

    // MARK: - Half split (negative / positive)

    @ViewBuilder
    private var halfSplitSection: some View {
        if !result.trackPoints.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Pacing Strategy", subtitle: "first vs second half")
                HalfSplitPanel(trackPoints: result.trackPoints)
            }
        }
    }

    // MARK: - HR Zones

    @ViewBuilder
    private var hrZoneSection: some View {
        let hasHR = result.trackPoints.contains { ($0.heartRate ?? 0) > 0 }
        if hasHR {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "HR Zones", subtitle: userMaxHR > 0 ? "max \(userMaxHR) bpm" : "Settings → Heart Rate")
                HRZoneBars(trackPoints: result.trackPoints)
            }
        }
    }

    // MARK: - Pace Zones (relative to plan)

    @ViewBuilder
    private var paceZoneSection: some View {
        if let plan = linkedPlan, !result.lapData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "Pace Zones",
                    subtitle: plan.name.isEmpty ? "vs target" : "vs \(plan.name)"
                )
                PaceZoneBars(laps: result.lapData, targetPaceSecPerKm: plan.paceSecPerKm)
            }
        }
    }

    // MARK: - Cadence / Power / Speed / Temperature profiles

    @ViewBuilder
    private var cadenceSection: some View {
        if result.trackPoints.contains(where: { ($0.cadence ?? 0) > 0 }) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Cadence")
                CadenceProfileChart(trackPoints: result.trackPoints)
            }
        }
    }

    @ViewBuilder
    private var powerSection: some View {
        if result.trackPoints.contains(where: { ($0.powerW ?? 0) > 0 }) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Power")
                PowerProfileChart(trackPoints: result.trackPoints)
            }
        }
    }

    @ViewBuilder
    private var speedSection: some View {
        if result.trackPoints.contains(where: { ($0.speedMs ?? 0) > 0 }) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Speed")
                SpeedProfileChart(trackPoints: result.trackPoints)
            }
        }
    }

    @ViewBuilder
    private var temperatureSection: some View {
        if result.trackPoints.contains(where: { $0.temperatureC != nil }) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Temperature")
                TemperatureProfileChart(trackPoints: result.trackPoints)
            }
        }
    }

    // MARK: - GAP

    @ViewBuilder
    private var gapSection: some View {
        if result.trackPoints.contains(where: { $0.altitudeM != nil }), result.trackPoints.count >= 5 {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Grade-Adjusted Pace", subtitle: "GAP vs raw pace")
                GAPOverlayChart(trackPoints: result.trackPoints)
            }
        }
    }

    // MARK: - Plan vs Actual

    @ViewBuilder
    private var planVsActualSection: some View {
        if let plan = linkedPlan, !result.lapData.isEmpty {
            let deltas = AdvancedAnalytics.planLapDeltas(
                actual: result.lapData,
                targetSecPerKm: plan.paceSecPerKm
            )
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "Plan vs Actual",
                    subtitle: plan.name.isEmpty ? "linked plan" : plan.name
                )
                CumulativeGapChart(deltas: deltas)
                PlanVsActualTable(deltas: deltas, planName: plan.name.isEmpty ? "plan" : plan.name)
            }
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
