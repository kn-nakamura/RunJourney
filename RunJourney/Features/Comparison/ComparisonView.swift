import SwiftUI
import SwiftData

/// 2〜4 件の RaceResult を重ね描きする比較画面。
/// 既存の `MultiResultLapPaceChart` / `FinishTimeComparisonChart` を流用し、
/// HR overlay / 累積タイム / Stats table を追加する。
struct ComparisonView: View {
    @Query(sort: \RaceResult.raceDate, order: .reverse) private var allResults: [RaceResult]

    @State private var selectedIds: Set<UUID>
    @State private var showPicker = false
    let lockedCategory: RaceCategory?

    /// 共通カラーパレット。`MultiResultLapPaceChart.palette` と整合。
    private static let palette: [Color] = [
        .accentPrimary,
        .cat10K,
        .cat5K,
        .catTrail,
        .catUltra100K
    ]

    /// `seedResults` から最大 4 件、もしくは指定 ID 群で初期化する。
    init(seedResults: [RaceResult] = [], seedIds: [UUID] = []) {
        let trimmed = seedResults.prefix(4).map(\.id)
        let combined = seedIds.isEmpty ? Array(trimmed) : seedIds
        _selectedIds = State(initialValue: Set(combined))
        // 全 seed が同カテゴリならロック (混在防止)。
        let cats = Set(seedResults.compactMap { $0.race?.category })
        self.lockedCategory = cats.count == 1 ? cats.first : nil
    }

    private var selectedResults: [RaceResult] {
        // selectedIds の順序は不定なので、表示は raceDate 降順で安定化させる。
        allResults
            .filter { selectedIds.contains($0.id) }
            .sorted { $0.raceDate > $1.raceDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if selectedResults.count < 2 {
                    emptyState
                } else {
                    statsTableSection
                    finishTimeSection
                    lapPaceSection
                    hrOverlaySection
                    cumulativeSection
                }
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle("Compare")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPicker = true
                } label: {
                    Label("Edit selection", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ComparisonPickerSheet(
                initialSelection: Array(selectedIds),
                lockedCategory: lockedCategory ?? selectedResults.first?.race?.category
            ) { ids in
                selectedIds = Set(ids)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(selectedResults.prefix(4).enumerated()), id: \.element.id) { idx, r in
                    chip(r, color: Self.palette[idx % Self.palette.count])
                }
                Spacer()
            }
            if let cat = selectedResults.first?.race?.category {
                Text(cat.displayName.uppercased())
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func chip(_ r: RaceResult, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(r.raceDate.formatted(date: .numeric, time: .omitted))
                .appText(.bodyXs)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary, in: Capsule())
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Pick 2+ Results",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Tap the slider button to pick 2 to 4 results from the same category.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Sections

    private var statsTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Stats")
            ComparisonStatsTable(results: selectedResults, palette: Self.palette)
        }
    }

    private var finishTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Finish Time")
            FinishTimeComparisonChart(results: selectedResults)
        }
    }

    private var lapPaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Lap Pace Overlay")
            MultiResultLapPaceChart(results: selectedResults)
        }
    }

    private var hrOverlaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Heart Rate")
            HRProfileOverlayChart(results: selectedResults, palette: Self.palette)
        }
    }

    private var cumulativeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Cumulative Time", subtitle: "by distance")
            CumulativeTimeOverlayChart(results: selectedResults, palette: Self.palette)
        }
    }
}
