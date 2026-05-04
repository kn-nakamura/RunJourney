import SwiftUI
import SwiftData

/// レース一覧ドロワー / 地図ピンの両方を駆動する共有フィルター。
/// 親 (`RaceMapView`) が単一の真実として持ち、`RaceListDrawer` には binding で渡す。
/// これにより「ドロワーで絞ると map のピンも同じ条件で減る」挙動になる。
///
/// 各フィールドの意味:
/// - `searchText`: name / city の部分一致 (大小文字無視)
/// - `category`: 単一カテゴリ pill。`nil` = すべて
/// - `year`: `createdAt` の年で絞る。`nil` = すべて
struct RaceFilters: Equatable {
    var searchText: String = ""
    var category: RaceCategory? = nil
    var year: Int? = nil

    var isActive: Bool {
        !searchText.isEmpty || category != nil || year != nil
    }

    /// 1 件のレースがフィルタを通過するか判定する。地図ピン側 (`mappableRaces`) と
    /// ドロワー側 (`filteredRaces`) の両方から呼ぶ。`createdAt` の年で照合するのは
    /// 旧来の `RaceListDrawer` の挙動を維持するため。
    func matches(_ race: Race) -> Bool {
        let cal = Calendar.current
        if let cat = category, race.category != cat { return false }
        if let yr = year, cal.component(.year, from: race.createdAt) != yr { return false }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            let nameMatch = race.name.lowercased().contains(q)
            let cityMatch = (race.city ?? "").lowercased().contains(q)
            if !(nameMatch || cityMatch) { return false }
        }
        return true
    }
}

/// マップ画面左上のハンバーガーから開くレース一覧ドロワー。
/// (Web 版 marathon-record-app の `src/components/layout/Sidebar.tsx` 相当)
///
/// 機能:
/// - 検索 (name / city)
/// - カテゴリ pill フィルタ (すべて + 各 RaceCategory)
/// - 年フィルタ (createdAt ベース)
/// - 行タップで `onSelect(race)` を呼び出して親にレース選択を通知
///
/// フィルタ状態 (`filters`) は親が所有する `@State`。地図ピンと共有することで
/// ドロワーの絞り込みが地図にもそのまま反映される。
struct RaceListDrawer: View {
    let races: [Race]
    @Binding var filters: RaceFilters
    let onSelect: (Race) -> Void

    private var availableYears: [Int] {
        let cal = Calendar.current
        let years = Set(races.map { cal.component(.year, from: $0.createdAt) })
        return years.sorted(by: >)
    }

    /// 最新結果の日付で降順、結果のないレースは末尾（同列は名前順）。
    private var filteredRaces: [Race] {
        races
            .filter(filters.matches)
            .sorted { lhs, rhs in
                let lhsDate = (lhs.results ?? []).map(\.raceDate).max()
                let rhsDate = (rhs.results ?? []).map(\.raceDate).max()
                switch (lhsDate, rhsDate) {
                case let (l?, r?):
                    if l != r { return l > r }
                    return lhs.name < rhs.name
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return lhs.name < rhs.name
                }
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterRow
                if !availableYears.isEmpty {
                    yearRow
                }
                Divider().opacity(0.3)
                content
            }
            .background(Color.bgPrimary)
            .navigationTitle("RACES (\(filteredRaces.count))")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    // MARK: - Sub views

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by name or city", text: $filters.searchText)
                .textFieldStyle(.plain)
                .font(.appFont(.bodySm))
            if !filters.searchText.isEmpty {
                Button { filters.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", isActive: filters.category == nil, color: .accentPrimary) {
                    filters.category = nil
                }
                ForEach(RaceCategory.allCases) { cat in
                    FilterPill(
                        label: cat.displayName,
                        isActive: filters.category == cat,
                        color: cat.pinColor
                    ) {
                        filters.category = (filters.category == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }

    private var yearRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All Years", isActive: filters.year == nil, color: .accentPrimary) {
                    filters.year = nil
                }
                ForEach(availableYears, id: \.self) { yr in
                    FilterPill(
                        label: "\(yr)",
                        isActive: filters.year == yr,
                        color: .accentPrimary
                    ) {
                        filters.year = (filters.year == yr) ? nil : yr
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        if filteredRaces.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text(races.isEmpty ? "No races yet" : "No matching races")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredRaces) { race in
                        Button {
                            onSelect(race)
                        } label: {
                            RaceListRow(race: race)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Row

private struct RaceListRow: View {
    let race: Race

    /// 有効（DNF/DNS でなく、タイムが正の値）な結果のみ。PB/SB 判定に使う。
    private var validResults: [RaceResult] {
        (race.results ?? []).filter { !$0.isDNF && !$0.isDNS && ($0.finishTimeSec ?? 0) > 0 }
    }

    /// 直近の結果（DNF/DNS 含む）。日付が同じ場合は createdAt の新しい方。
    private var latestResult: RaceResult? {
        (race.results ?? [])
            .max { lhs, rhs in
                if lhs.raceDate != rhs.raceDate { return lhs.raceDate < rhs.raceDate }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// このレース内 PB（最速タイム）に最新結果が一致しているか。
    private var isLatestPB: Bool {
        guard let latest = latestResult, let latestSec = latest.finishTimeSec else { return false }
        guard let pbSec = validResults.compactMap(\.finishTimeSec).min() else { return false }
        return latestSec == pbSec
    }

    /// 同年内 SB に一致しているか（PB のときは PB を優先するので false）。
    private var isLatestSB: Bool {
        guard !isLatestPB,
              let latest = latestResult,
              let latestSec = latest.finishTimeSec else { return false }
        let cal = Calendar.current
        let year = cal.component(.year, from: latest.raceDate)
        let sameYearMin = validResults
            .filter { cal.component(.year, from: $0.raceDate) == year }
            .compactMap(\.finishTimeSec)
            .min()
        guard let sbSec = sameYearMin else { return false }
        return latestSec == sbSec
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左バッジ (カテゴリ色)
            ZStack {
                Circle()
                    .fill(race.category.pinColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: race.category.symbolName)
                    .foregroundStyle(race.category.pinColor)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(race.name.isEmpty ? "(Untitled)" : race.name)
                        .appText(.bodySmBold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if isLatestPB {
                        badgeLabel("PB", background: Color.pbBadge)
                    } else if isLatestSB {
                        badgeLabel("SB", background: Color.sbBadge)
                    }
                }
                HStack(spacing: 6) {
                    Text(race.category.displayName)
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    if let city = race.city, !city.isEmpty {
                        Text("· \(city)").appText(.bodyXs).foregroundStyle(.tertiary)
                    }
                    if let latest = latestResult {
                        Text("· \(formatDate(latest.raceDate))")
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            trailingValue
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var trailingValue: some View {
        if let latest = latestResult {
            if let sec = latest.finishTimeSec, sec > 0 {
                Text(formatDuration(sec))
                    .appText(.codeBaseBold)
                    .foregroundStyle(Color.accentPrimary)
            } else if latest.isDNF {
                Text("DNF")
                    .appText(.codeXsBold)
                    .foregroundStyle(.red)
            } else if latest.isDNS {
                Text("DNS")
                    .appText(.codeXsBold)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badgeLabel(_ text: String, background: Color) -> some View {
        Text(text)
            .appText(.badgeNumeric)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
            .foregroundStyle(.black)
    }

    private func formatDuration(_ totalSec: Double) -> String {
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
}

