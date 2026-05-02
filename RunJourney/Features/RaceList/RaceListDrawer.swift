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

    private var filteredRaces: [Race] {
        races.filter(filters.matches)
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

    private var resultCount: Int { race.results?.count ?? 0 }

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

            VStack(alignment: .leading, spacing: 2) {
                Text(race.name.isEmpty ? "(Untitled)" : race.name)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(race.category.displayName)
                        .appText(.bodyXs)
                        .foregroundStyle(.secondary)
                    if let city = race.city, !city.isEmpty {
                        Text("· \(city)").appText(.bodyXs).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if resultCount > 0 {
                Text("\(resultCount)")
                    .appText(.badgeNumeric)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentPrimary, in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

