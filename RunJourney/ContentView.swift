import SwiftUI
import SwiftData

/// アプリのルート画面。Phase 2 で MapKit ベースの RaceMapView に置き換える予定。
/// 現状は登録済みレースの一覧と簡易追加機能のプレースホルダー。
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            raceList
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            placeholderDetail
        }
#else
        NavigationStack {
            raceList
        }
#endif
    }

    private var raceList: some View {
        List {
            if races.isEmpty {
                ContentUnavailableView(
                    "まだレースが登録されていません",
                    systemImage: "figure.run",
                    description: Text("右上の + からダミーレースを追加できます。Phase 3 で TCX/GPX/FIT 取り込みに置き換えます。")
                )
            } else {
                ForEach(races) { race in
                    NavigationLink {
                        RaceDetailPlaceholder(race: race)
                    } label: {
                        RaceRow(race: race)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("RunJourney")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addDummy) {
                    Label("レース追加", systemImage: "plus")
                }
            }
        }
    }

    private var placeholderDetail: some View {
        Text("レースを選択してください")
            .foregroundStyle(.secondary)
    }

    private func addDummy() {
        let dummy = Race(
            name: "東京マラソン \(Calendar.current.component(.year, from: .now))",
            category: .fullMarathon,
            address: "東京都新宿区",
            city: "Tokyo",
            country: "Japan",
            lat: 35.6909,
            lng: 139.6917
        )
        modelContext.insert(dummy)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(races[index])
        }
    }
}

private struct RaceRow: View {
    let race: Race

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: race.category.symbolName)
                .foregroundStyle(race.category.pinColor)
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(race.name.isEmpty ? "(無題のレース)" : race.name)
                    .font(.headline)
                Text("\(race.category.displayName) ・ \(race.city ?? race.country)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let count = race.results?.count, count > 0 {
                Text("\(count)回")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RaceDetailPlaceholder: View {
    let race: Race

    var body: some View {
        Form {
            Section("基本情報") {
                LabeledContent("名前", value: race.name)
                LabeledContent("カテゴリ", value: race.category.displayName)
                if let km = race.distanceKm {
                    LabeledContent("距離", value: String(format: "%.2f km", km))
                }
                LabeledContent("地点", value: "\(race.lat), \(race.lng)")
            }
            Section("結果 (\(race.results?.count ?? 0)件)") {
                Text("Phase 4 で結果一覧UIを実装します")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(race.name)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Race.self, RaceResult.self], inMemory: true)
}
