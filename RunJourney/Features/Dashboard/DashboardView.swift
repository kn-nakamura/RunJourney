import SwiftUI
import SwiftData
import Charts

/// 統計ダッシュボード。総走行・PB一覧・年別/カテゴリ別チャート。
/// カテゴリ pill で結果を絞り込める (Web 版 marathon-record-app の DashboardPage 相当)。
struct DashboardView: View {
    @Query(sort: \RaceResult.raceDate, order: .reverse) private var results: [RaceResult]

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
                if !results.isEmpty {
                    categoryFilterPills
                }
                if filteredResults.isEmpty {
                    emptyState
                } else {
                    summaryGrid
                    pbBoardSection
                    yearChartSection
                    if selectedCategory == nil {
                        categoryChartSection
                    }
                }
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .navigationTitle("ダッシュボード")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }

    // MARK: - Category filter pills

    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DashboardFilterPill(label: "すべて", isActive: selectedCategory == nil, color: .accentPrimary) {
                    selectedCategory = nil
                }
                ForEach(RaceCategory.allCases) { cat in
                    DashboardFilterPill(label: cat.displayName, isActive: selectedCategory == cat, color: cat.pinColor) {
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
                "まだデータがありません",
                systemImage: "chart.bar.xaxis",
                description: Text("地図画面の取り込みボタン ↓ から TCX/GPX/FIT/ZIP を取り込むと、ここに統計が表示されます。")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            ContentUnavailableView(
                "該当データがありません",
                systemImage: "magnifyingglass",
                description: Text("選択中のカテゴリには結果が登録されていません。「すべて」または別のカテゴリを選択してください。")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Stats summary grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(label: "完走数", value: "\(aggregate.totalRaces)", unit: "回", symbol: "flag.checkered", color: .accentPrimary)
            StatCard(label: "総距離", value: String(format: "%.1f", aggregate.totalDistanceM / 1000), unit: "km", symbol: "ruler", color: .cat10K)
            StatCard(label: "総時間", value: formatTotalTime(aggregate.totalTimeSec), unit: "", symbol: "clock", color: .cat5K)
            if let pace = aggregate.weightedAvgPaceSecPerKm {
                StatCard(label: "平均ペース", value: formatPace(pace), unit: "/km", symbol: "speedometer", color: .catHalfMarathon)
            }
        }
    }

    // MARK: - PB Board

    private var pbBoardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("自己ベスト (PB)", subtitle: "カテゴリ別")
            VStack(spacing: 10) {
                ForEach(RaceCategory.allCases) { cat in
                    if let result = pbs[cat] {
                        PBCard(category: cat, result: result)
                    }
                }
                if pbs.isEmpty {
                    Text("PB はまだ登録されていません")
                        .font(.body(13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    // MARK: - Year chart

    private var yearChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("年別レース数")
            if yearCounts.isEmpty {
                Text("年別データなし")
                    .font(.body(13))
                    .foregroundStyle(.secondary)
            } else {
                Chart(yearCounts, id: \.year) { item in
                    BarMark(
                        x: .value("年", "\(item.year)"),
                        y: .value("件数", item.count)
                    )
                    .foregroundStyle(Color.accentPrimary.gradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(item.count)")
                            .font(.mono(11, bold: true))
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel().font(.mono(10))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.mono(10)) }
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
            sectionHeader("カテゴリ別レース数")
            if categoryCounts.isEmpty {
                Text("カテゴリデータなし")
                    .font(.body(13))
                    .foregroundStyle(.secondary)
            } else {
                Chart(categoryCounts, id: \.category) { item in
                    SectorMark(
                        angle: .value("件数", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.category.pinColor)
                    .annotation(position: .overlay) {
                        Text("\(item.count)")
                            .font(.mono(10, bold: true))
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
                                .font(.body(12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section header

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

    // MARK: - Formatters

    private func formatTotalTime(_ totalSec: Double) -> String {
        guard totalSec > 0 else { return "—" }
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h >= 24 {
            let days = h / 24
            let remH = h % 24
            return "\(days)日\(remH)時間"
        }
        if h > 0 { return "\(h)時間\(m)分" }
        return "\(m)分"
    }

    private func formatPace(_ secPerKm: Double) -> String {
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Subcomponents

private struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body(11))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.display(26))
                        .foregroundStyle(Color.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.body(11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PBCard: View {
    let category: RaceCategory
    let result: RaceResult

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.pinColor.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: category.symbolName)
                    .foregroundStyle(category.pinColor)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body(11))
                    .foregroundStyle(.secondary)
                Text(result.race?.name ?? "—")
                    .font(.body(14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(result.raceDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.body(11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(result.finishTimeSec ?? 0))
                    .font(.display(24))
                    .foregroundStyle(Color.accentPrimary)
                Text("PB")
                    .font(.monoCaption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.pbBadge, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Filter pill

private struct DashboardFilterPill: View {
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body(12, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Color.black : Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isActive ? color : Color.bgSecondary,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? .clear : .white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (凡例の折り返し用)

/// 子ビューを左→右→必要なら次の行にラップする簡易レイアウト。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if currentLineWidth + s.width > width {
                totalHeight += currentLineHeight + spacing
                maxWidth = max(maxWidth, currentLineWidth - spacing)
                currentLineWidth = 0
                currentLineHeight = 0
            }
            currentLineWidth += s.width + spacing
            currentLineHeight = max(currentLineHeight, s.height)
        }
        totalHeight += currentLineHeight
        maxWidth = max(maxWidth, currentLineWidth - spacing)
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if origin.x + s.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: origin, proposal: ProposedViewSize(s))
            origin.x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
