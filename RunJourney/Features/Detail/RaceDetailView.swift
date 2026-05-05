import SwiftUI
import SwiftData

/// 大会(Race)の詳細ビュー。
/// - 基本情報（名前・カテゴリ・距離・地点）
/// - 結果一覧（複数の参加結果、各行は RaceResultDetailView へナビゲート）
/// - 比較セクション（2件以上ある場合: 年別タイム棒グラフ + ラップペース重ね合わせ）
/// - 画面最下部の小さな🗑から `RaceDeleteSheet` を開き、結果のみ削除 / レース丸ごと削除を選択（誤操作防止）
struct RaceDetailView: View {
    @Bindable var race: Race
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    @State private var showComparison = false
    @State private var showDeleteSheet = false
    @State private var showAddResultSheet = false
    @State private var pendingDeleteOffsets: IndexSet?

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
            headerSection
            basicInfoSection
            attachmentsSection
            photosSection
            resultsSection
            if sortedResults.count >= 2 {
                comparisonSection
            }
            deleteEntrySection
        }
        .navigationTitle(race.name.isEmpty ? "(Untitled)" : race.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showDeleteSheet) {
            RaceDeleteSheet(race: race) {
                dismiss()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddResultSheet) {
            AddResultSheet(race: race)
        }
        .confirmationDialog(
            "Delete this result?",
            isPresented: Binding(
                get: { pendingDeleteOffsets != nil },
                set: { if !$0 { pendingDeleteOffsets = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDeleteOffsets {
                    for o in offsets {
                        let result = sortedResults[o]
                        AttachmentStore.deleteAll(ownerID: result.id)
                        modelContext.delete(result)
                    }
                    try? modelContext.save()
                }
                pendingDeleteOffsets = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteOffsets = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Delete entry (画面最下部の控えめな🗑)
    //
    // Settings の "Delete data..." と同じく、目立たない gray の小さな行として置く。
    // タップで `RaceDeleteSheet` を開き、結果のみ削除するか、レース丸ごと削除するかを選ぶ。

    private var deleteEntrySection: some View {
        Section {
            Button {
                showDeleteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Delete...")
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            RaceHeaderView(race: race)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - Basic info

    private var basicInfoSection: some View {
        Section {
            // 1. Race Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Race Name")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                TextField("e.g. Tokyo Marathon", text: $race.name)
            }

            // 2. Category
            VStack(alignment: .leading, spacing: 4) {
                Text("Category")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Menu {
                    Picker("Category", selection: $race.category) {
                        ForEach(RaceCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.symbolName).tag(cat)
                        }
                    }
                } label: {
                    HStack {
                        Label(race.category.displayName, systemImage: race.category.symbolName)
                            .appText(.bodyBaseBold)
                            .foregroundStyle(Color.accentPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
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
                Text("Website")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                TextField("https://...", text: $race.websiteURL.bound)
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

            // 6. Race Logo (PhotosPicker + URL)
            VStack(alignment: .leading, spacing: 8) {
                Text("Race Logo")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                LogoPicker(race: race)
                RaceLogoUrlField(race: race)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Distance")
                .appText(.bodyXs)
                .foregroundStyle(.secondary)
            if race.category.defaultDistanceKm != nil {
                // 自動 (read-only)
                HStack(alignment: .firstTextBaseline) {
                    Text(PaceUtils.formatDistanceValue(km: race.distanceKm ?? 0, in: unit))
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                    Text(unit.label)
                        .appText(.codeXs)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                // Trail / UltraCustom — ユーザー入力
                HStack {
                    TextField("e.g. 50", text: distanceUnitBinding)
                        .keyboardType(.decimalPad)
                    Text(unit.label)
                        .appText(.codeXs)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var distanceUnitBinding: Binding<String> {
        Binding<String>(
            get: {
                guard let km = race.distanceKm else { return "" }
                let v = km.displayed(in: unit)
                return v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(v))
                    : String(format: "%g", v)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    race.distanceKm = nil
                } else if let d = Double(trimmed) {
                    race.distanceKm = d.toKm(from: unit)
                }
            }
        )
    }

    // MARK: - Attachments / Photos

    private var attachmentsSection: some View {
        AttachmentSection(owner: race)
    }

    private var photosSection: some View {
        PhotoLinkSection(owner: race)
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
                Text("Tap + to add a result manually, or import a TCX / GPX / FIT / ZIP file from inside the sheet.")
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
                    pendingDeleteOffsets = offsets
                }
            }
        } header: {
            SectionHeader(title: "Results", subtitle: "\(sortedResults.count)") {
                Button {
                    showAddResultSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Result")
            }
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
                    if sortedResults.count >= 2 {
                        NavigationLink {
                            ComparisonView(seedResults: sortedResults)
                        } label: {
                            Label("Open detailed comparison…", systemImage: "chart.line.uptrend.xyaxis")
                                .appText(.bodySmBold)
                                .foregroundStyle(Color.accentPrimary)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Year-over-Year", systemImage: "chart.line.uptrend.xyaxis")
                    .appText(.bodyBaseBold)
            }
        }
    }

}

/// 結果一覧の1行（RaceDetailViewから NavigationLink のラベルとして使う）。
struct RaceResultRow: View {
    let result: RaceResult
    let isPB: Bool

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

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
                    Label(PaceUtils.formatDistance(km: dist / 1000, in: unit), systemImage: "ruler")
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
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: unit)
        let m = displayed / 60
        let s = displayed % 60
        return String(format: "%d:%02d \(unit.perLabel)", m, s)
    }
}
