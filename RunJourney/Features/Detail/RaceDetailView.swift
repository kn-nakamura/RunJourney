import SwiftUI
import SwiftData

/// 大会(Race)の詳細ビュー。
/// - 基本情報（名前・カテゴリ・距離・地点）
/// - 結果一覧（複数の参加結果、各行は RaceResultDetailView へナビゲート）
/// - 比較セクション（2件以上ある場合: 年別タイム棒グラフ + ラップペース重ね合わせ）
/// - 大会自体の削除
struct RaceDetailView: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showComparison = false

    private var sortedResults: [RaceResult] {
        (race.results ?? []).sorted { $0.raceDate > $1.raceDate }
    }

    private var pbSeconds: Double? {
        sortedResults
            .compactMap { ($0.isDNF || $0.isDNS) ? nil : $0.finishTimeSec }
            .min()
    }

    var body: some View {
        Form {
            basicInfoSection
            resultsSection
            if sortedResults.count >= 2 {
                comparisonSection
            }
            deleteSection
        }
        .navigationTitle(race.name.isEmpty ? "(Untitled)" : race.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    // MARK: - Basic info

    private var basicInfoSection: some View {
        Section {
            // 1. Race Name
            TextField("Race Name", text: $race.name)

            // 2. Category
            Picker("Category", selection: $race.category) {
                ForEach(RaceCategory.allCases) { cat in
                    Label(cat.displayName, systemImage: cat.symbolName)
                        .tag(cat)
                }
            }

            // 3. Distance — 5K/10K/Half/Full/Ultra100K は自動、Trail/UltraCustom は手動入力
            distanceField

            // 4. Location — MKLocalSearch で住所検索
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                LocationSearchField(race: race)
            }

            // 5. Website
            VStack(alignment: .leading, spacing: 4) {
                TextField("Website", text: $race.websiteURL.bound, prompt: Text("https://..."))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let url = validWebsiteURL {
                    Link(destination: url) {
                        Label("Open official site", systemImage: "safari")
                            .appText(.bodyXs)
                    }
                }
            }

            // 6. Race Logo
            VStack(alignment: .leading, spacing: 4) {
                Text("Race Logo")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                LogoPicker(race: race)
            }
        } header: {
            SectionHeader(title: "Race Info")
        }
        .onChange(of: race.category) { _, newCategory in
            // カテゴリ変更時に自動距離を再計算。Trail/UltraCustom はユーザー入力を維持。
            if let auto = newCategory.defaultDistanceKm {
                race.distanceKm = auto
            }
        }
    }

    @ViewBuilder
    private var distanceField: some View {
        if race.category.defaultDistanceKm != nil {
            // 自動 (read-only)
            LabeledContent("Distance") {
                Text(String(format: "%.3f km", race.distanceKm ?? 0))
                    .appText(.codeMd)
                    .foregroundStyle(Color.textPrimary)
            }
        } else {
            // Trail / UltraCustom — ユーザー入力
            HStack {
                Text("Distance")
                Spacer()
                TextField("e.g. 50", text: $race.distanceKm.stringBound)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
                Text("km")
                    .appText(.codeXs)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var validWebsiteURL: URL? {
        guard let raw = race.websiteURL?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    // MARK: - Results

    private var resultsSection: some View {
        Section {
            if sortedResults.isEmpty {
                Text("No results yet")
                    .foregroundStyle(.secondary)
                Text("Import TCX / GPX / FIT / ZIP from the Map toolbar, then choose \"Attach to existing race\" in the import confirmation sheet to associate the result with this race.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(sortedResults) { result in
                    NavigationLink {
                        RaceResultDetailView(result: result)
                    } label: {
                        RaceResultRow(result: result, isPB: result.finishTimeSec == pbSeconds && pbSeconds != nil)
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(sortedResults[offset])
                    }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Results", subtitle: "\(sortedResults.count)")
        } footer: {
            if sortedResults.count >= 2 {
                Text("Tap a row for details and charts. Open \"Year-over-Year\" below to overlay multiple results.")
            }
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showComparison) {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedResults.contains(where: { ($0.finishTimeSec ?? 0) > 0 }) {
                        Text("Finish Time")
                            .appText(.bodySmBold)
                            .foregroundStyle(.secondary)
                        FinishTimeComparisonChart(results: sortedResults)
                    }
                    if sortedResults.contains(where: { !$0.lapData.isEmpty }) {
                        Text("Lap Pace Overlay")
                            .appText(.bodySmBold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        MultiResultLapPaceChart(results: sortedResults)
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Year-over-Year", systemImage: "chart.line.uptrend.xyaxis")
                    .appText(.bodyBaseBold)
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                modelContext.delete(race)
                try? modelContext.save()
                dismiss()
            } label: {
                Label("Delete Race", systemImage: "trash")
            }
        } footer: {
            if !sortedResults.isEmpty {
                Text("Deleting also removes the \(sortedResults.count) linked result(s).")
            }
        }
    }
}

/// 結果一覧の1行（RaceDetailViewから NavigationLink のラベルとして使う）。
struct RaceResultRow: View {
    let result: RaceResult
    let isPB: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .appText(.bodyBaseBold)
                if isPB {
                    Text("PB")
                        .appText(.badgeNumeric)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pbBadge, in: Capsule())
                        .foregroundStyle(.black)
                }
                Spacer()
                if let sec = result.finishTimeSec {
                    Text(formatDuration(sec))
                        .appText(.codeLg)
                        .foregroundStyle(Color.accentPrimary)
                } else if result.isDNF {
                    Text("DNF").foregroundStyle(.red)
                } else if result.isDNS {
                    Text("DNS").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let dist = result.summary?.totalDistanceM {
                    Label(String(format: "%.2f km", dist / 1000), systemImage: "ruler")
                        .appText(.codeXs)
                }
                if let pace = result.summary?.avgPaceSecPerKm {
                    Label(formatPace(pace), systemImage: "speedometer")
                        .appText(.codeXs)
                }
                if let hr = result.summary?.avgHeartRate {
                    Label("\(hr) bpm", systemImage: "heart.fill")
                        .appText(.codeXs)
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
            .foregroundStyle(.secondary)

            if !result.lapData.isEmpty || !result.trackPoints.isEmpty {
                HStack(spacing: 12) {
                    if !result.lapData.isEmpty {
                        Text("\(result.lapData.count) laps")
                    }
                    if !result.trackPoints.isEmpty {
                        Text("\(result.trackPoints.count) pts")
                    }
                    if let elev = result.summary?.elevationGainM {
                        Text(String(format: "↑ %.0f m", elev))
                    }
                    if let cal = result.summary?.totalCalories {
                        Text(String(format: "%.0f kcal", cal))
                    }
                }
                .font(.appFont(.codeXs))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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
