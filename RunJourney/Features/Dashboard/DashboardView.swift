import SwiftUI
import SwiftData
import Charts

/// 統計ダッシュボード。総走行・PB一覧・年別/カテゴリ別チャート。
/// カテゴリ pill で結果を絞り込める (Web 版 marathon-record-app の DashboardPage 相当)。
struct DashboardView: View {
    @Query(sort: \RaceResult.raceDate, order: .reverse) private var results: [RaceResult]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    /// 端末サイズに応じたカラム数調整。`ContentView` で注入される。
    @Environment(\.adaptiveLayout) private var layout

    @State private var selectedCategory: RaceCategory? = nil  // nil = すべて

    private var filteredResults: [RaceResult] {
        guard let cat = selectedCategory else { return results }
        return results.filter { $0.race?.category == cat }
    }

    private var aggregate: PBCalculator.AggregateStats {
        PBCalculator.aggregate(from: filteredResults)
    }
    private var pbs: [RaceCategory: RaceResult] {
        PBCalculator.personalBests(from: filteredResults)
    }
    private var yearCounts: [(year: Int, count: Int)] {
        PBCalculator.countsByYear(from: filteredResults)
    }
    private var categoryCounts: [(category: RaceCategory, count: Int)] {
        PBCalculator.countsByCategory(from: filteredResults)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 横向き iPhone は縦余白が貴重なので、display 級の見出しは
                // やや小さい middle ヘッダーに切替えて折りたたみ感を出す。
                Text("Dashboard")
                    .appText(layout.isVerticallyCompact ? .displayMd : .displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !results.isEmpty {
                    categoryFilterPills
                }
                if filteredResults.isEmpty {
                    emptyState
                } else if selectedCategory == nil {
                    allModeSections
                } else {
                    categoryModeSections
                }
            }
            .padding(layout.standardPadding)
            .frame(maxWidth: layout.contentMaxWidth ?? .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.bgPrimary)
#if os(iOS)
        // iOS 26 のナビバーは UIAppearance で Bebas Neue を当てても取りこぼすことが
        // あるので、ナビバー自体は非表示にして ScrollView の中に見出しを置く
        // (Web 版の `<h1>DASHBOARD</h1>` と同じパターン)。
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    // MARK: - Adaptive grid columns

    /// StatCard 用 (小さいカード) のカラム数。横向き iPhone で 3、iPad/Mac で 4。
    private var statColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: layout.statCardColumnCount)
    }

    /// PB ボード行・summary 4 枚など中程度カードのカラム数。
    private var mediumColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: layout.mediumCardColumnCount)
    }

    // MARK: - All mode (selectedCategory == nil)
    //
    // "All" は距離が混在するので、平均ペースのような単一指標は意味を持たない。
    // 代わりにアクティビティの「広がり」(年数・国・大会数) と「進捗」(年別距離・PB 推移)
    // を中心に並べ、distribution カードで季節性を可視化する。
    //
    // wide / phoneLandscape では Activity と PB Board を横に並べて、
    // 余った幅を活かす。

    @ViewBuilder
    private var allModeSections: some View {
        if layout.prefersMultiColumn {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 20) {
                    activityGroupSection
                    progressGroupSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 20) {
                    pbBoardSection
                    distributionGroupSection
                    yearChartSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            activityGroupSection
            pbBoardSection
            progressGroupSection
            distributionGroupSection
            yearChartSection
        }
    }

    // MARK: - Category mode

    @ViewBuilder
    private var categoryModeSections: some View {
        if layout.prefersMultiColumn {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 20) {
                    summaryGrid
                    pbBoardSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 20) {
                    if let cat = selectedCategory {
                        categoryProgressionSection(category: cat)
                        paceDistributionSection(category: cat)
                    }
                    yearChartSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            summaryGrid
            pbBoardSection
            if let cat = selectedCategory {
                categoryProgressionSection(category: cat)
                paceDistributionSection(category: cat)
            }
            yearChartSection
        }
    }

    // MARK: - Category filter pills

    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", isActive: selectedCategory == nil, color: .accentPrimary) {
                    Haptics.tap()
                    selectedCategory = nil
                }
                ForEach(RaceCategory.allCases) { cat in
                    FilterPill(label: cat.displayName, isActive: selectedCategory == cat, color: cat.pinColor) {
                        Haptics.tap()
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if results.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.bar.xaxis",
                description: Text("Import TCX / GPX / FIT / ZIP from the Map tab to see your stats here.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            ContentUnavailableView(
                "No Matching Data",
                systemImage: "magnifyingglass",
                description: Text("No results in the selected category. Pick \"All\" or another category.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Stats summary grid (Category mode のみ)
    //
    // distance が揃っているカテゴリ単独モードでは Avg Pace が意味を持つので 4 枚並べる。

    private var summaryGrid: some View {
        LazyVGrid(columns: statColumns, spacing: 12) {
            StatCard(label: "Finishes", value: "\(aggregate.totalRaces)", unit: "", symbol: "flag.checkered", color: .accentPrimary)
            StatCard(label: "Total Distance", value: PaceUtils.formatDistanceValue(km: aggregate.totalDistanceM / 1000, in: unit), unit: unit.label, symbol: "ruler", color: .cat10K)
            StatCard(label: "Total Time", value: PaceUtils.formatTotalTime(aggregate.totalTimeSec), unit: "", symbol: "clock", color: .cat5K)
            if let pace = aggregate.weightedAvgPaceSecPerKm {
                StatCard(label: "Avg Pace", value: PaceUtils.formatPaceShort(secPerKm: pace, in: unit), unit: unit.perLabel, symbol: "speedometer", color: .catHalfMarathon)
            }
        }
    }

    // MARK: - All mode: Activity group
    //
    // Avg Pace は意図的に外している (5K と Full の平均は無意味)。
    // 代わりに「どれだけ走ってきたか」を示すストリーク・ユニークレース・国数を並べる。

    private var activityGroupSection: some View {
        let streak = AdvancedAnalytics.longestRacingStreak(filteredResults)
        let mostActive = AdvancedAnalytics.mostActiveYear(filteredResults)
        let unique = AdvancedAnalytics.uniqueRaceCount(filteredResults)
        let countries = AdvancedAnalytics.countryCount(filteredResults)

        return MetricGroupCard(title: "Activity") {
            LazyVGrid(columns: statColumns, spacing: 12) {
                StatCard(label: "Finishes", value: "\(aggregate.totalRaces)", unit: "", symbol: "flag.checkered", color: .accentPrimary)
                StatCard(label: "Total Distance", value: PaceUtils.formatDistanceValue(km: aggregate.totalDistanceM / 1000, in: unit), unit: unit.label, symbol: "ruler", color: .cat10K)
                StatCard(label: "Total Time", value: PaceUtils.formatTotalTime(aggregate.totalTimeSec), unit: "", symbol: "clock", color: .cat5K)
                StatCard(label: "Longest Streak", value: streak > 0 ? "\(streak)" : "—", unit: streak > 0 ? "yr" : "", symbol: "flame.fill", color: .catUltra100K)
                if let m = mostActive {
                    StatCard(label: "Most-Active Year", value: "\(m.year)", unit: "\(m.count) races", symbol: "calendar", color: .catTrail)
                }
                StatCard(label: "Unique Races", value: "\(unique)", unit: "", symbol: "rosette", color: .cat10K)
                if countries > 0 {
                    StatCard(label: "Countries", value: "\(countries)", unit: "", symbol: "globe", color: .cat5K)
                }
            }
        }
    }

    // MARK: - All mode: Progress group (年別距離 + PB 推移)

    @ViewBuilder
    private var progressGroupSection: some View {
        let yearDistance = AdvancedAnalytics.distancePerYear(filteredResults)
        let pbProgression = AdvancedAnalytics.pbProgression(filteredResults)
        let hasPBProgression = pbProgression.values.contains { $0.count >= 2 }

        if !yearDistance.isEmpty || hasPBProgression {
            MetricGroupCard(title: "Progress") {
                if !yearDistance.isEmpty {
                    SectionHeader(title: "Distance per Year")
                    DistancePerYearChart(data: yearDistance)
                }
                if hasPBProgression {
                    SectionHeader(title: "PB Progression", subtitle: "by category")
                        .padding(.top, 6)
                    PBProgressionChart(data: pbProgression)
                }
            }
        }
    }

    // MARK: - All mode: Distribution group (カテゴリ donut + Month heatmap)

    @ViewBuilder
    private var distributionGroupSection: some View {
        let monthHeatmap = AdvancedAnalytics.monthHeatmap(filteredResults)

        MetricGroupCard(title: "Distribution") {
            if !categoryCounts.isEmpty {
                categoryChartSection
            }
            if !monthHeatmap.isEmpty {
                SectionHeader(title: "Month of Year")
                    .padding(.top, 6)
                MonthHeatmapChart(counts: monthHeatmap)
            }
        }
    }

    // MARK: - Category mode: PB progression for the single category

    @ViewBuilder
    private func categoryProgressionSection(category cat: RaceCategory) -> some View {
        let timeline = AdvancedAnalytics.finishTimeTimeline(filteredResults)
        if timeline.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Finish Time Trend", subtitle: cat.displayName)
                PBProgressionChart(data: [cat: timeline])
            }
        }
    }

    // MARK: - Category mode: pace histogram

    @ViewBuilder
    private func paceDistributionSection(category: RaceCategory) -> some View {
        let buckets = AdvancedAnalytics.paceHistogram(filteredResults, bucketSec: 15)
        if !buckets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Pace Distribution", subtitle: "15s buckets")
                PaceHistogramChart(buckets: buckets)
            }
        }
    }

    // MARK: - PB Board

    private var pbBoardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Personal Bests", subtitle: "by category")
            // 縦持ち iPhone は 1 列、横向き iPhone / iPad / Mac は 2 列で
            // PB カードを敷き詰める。
            LazyVGrid(columns: mediumColumns, spacing: 10) {
                ForEach(RaceCategory.allCases) { cat in
                    if let result = pbs[cat] {
                        NavigationLink {
                            RaceResultDetailView(result: result)
                        } label: {
                            PBCard(category: cat, result: result)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                        .contextMenu {
                            NavigationLink {
                                ComparisonView(seedResults: results.filter { $0.race?.category == cat })
                            } label: {
                                Label("Compare with…", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                    }
                }
            }
            if pbs.isEmpty {
                Text("No personal bests yet")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Year chart

    private var yearChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Races per Year")
            if yearCounts.isEmpty {
                Text("No yearly data")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            } else {
                Chart(yearCounts, id: \.year) { item in
                    BarMark(
                        x: .value("Year", "\(item.year)"),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.accentPrimary.gradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(item.count)")
                            .appText(.codeXxsBold)
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel().font(.appFont(.codeXxs))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.appFont(.codeXxs)) }
                }
                .frame(height: 160)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Category chart

    private var categoryChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Races by Category")
            if categoryCounts.isEmpty {
                Text("No category data")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            } else {
                Chart(categoryCounts, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.category.pinColor)
                    .annotation(position: .overlay) {
                        Text("\(item.count)")
                            .appText(.codeXxsBold)
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 220)
                .padding(.vertical, 8)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))

                // 凡例
                FlowLayout(spacing: 10) {
                    ForEach(categoryCounts, id: \.category) { item in
                        HStack(spacing: 6) {
                            Circle().fill(item.category.pinColor).frame(width: 8, height: 8)
                            Text("\(item.category.displayName) (\(item.count))")
                                .appText(.bodyXs)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

}
