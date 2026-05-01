import SwiftUI
import SwiftData

/// アプリのルート画面。
/// - iPhone: NavigationStack で MapView 1枚
/// - iPad/Mac: NavigationSplitView でサイドバー（レース一覧）+ MapView 2カラム
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    @State private var sidebarSelection: Race?

    var body: some View {
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitView
        } else {
            NavigationStack {
                RaceMapView()
            }
        }
#else
        splitView
#endif
    }

    private var splitView: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Section("レース一覧 (\(races.count))") {
                    if races.isEmpty {
                        Text("地図右上の + から追加")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(races) { race in
                            RaceSidebarRow(race: race)
                                .tag(race)
                        }
                    }
                }
            }
            .navigationTitle("RunJourney")
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            NavigationStack {
                RaceMapView()
            }
        }
    }
}

private struct RaceSidebarRow: View {
    let race: Race

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: race.category.symbolName)
                .foregroundStyle(race.category.pinColor)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(race.name.isEmpty ? "(無題)" : race.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(race.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Race.self, RaceResult.self], inMemory: true)
}
