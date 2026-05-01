import SwiftUI
import SwiftData

/// アプリのルート。
/// - iPhone (compact): TabView で Map / Dashboard を切替
/// - iPad / Mac (regular): NavigationSplitView の sidebar から切替
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedSection: AppSection? = .map

    enum AppSection: String, Hashable, CaseIterable, Identifiable {
        case map
        case dashboard

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .map: return "地図"
            case .dashboard: return "ダッシュボード"
            }
        }
        var symbolName: String {
            switch self {
            case .map: return "map"
            case .dashboard: return "chart.bar"
            }
        }
    }

    var body: some View {
#if os(iOS)
        if horizontalSizeClass == .compact {
            tabView
        } else {
            sidebarSplitView
        }
#else
        sidebarSplitView
#endif
    }

    // MARK: - iPhone

    private var tabView: some View {
        TabView(selection: tabSelectionBinding) {
            NavigationStack {
                RaceMapView()
            }
            .tabItem { Label(AppSection.map.displayName, systemImage: AppSection.map.symbolName) }
            .tag(AppSection.map)

            NavigationStack {
                DashboardView()
            }
            .tabItem { Label(AppSection.dashboard.displayName, systemImage: AppSection.dashboard.symbolName) }
            .tag(AppSection.dashboard)
        }
    }

    /// TabView は非 optional の selection を期待するので bridge する。
    private var tabSelectionBinding: Binding<AppSection> {
        Binding(
            get: { selectedSection ?? .map },
            set: { selectedSection = $0 }
        )
    }

    // MARK: - iPad / Mac

    private var sidebarSplitView: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("RunJourney") {
                    ForEach(AppSection.allCases) { section in
                        Label(section.displayName, systemImage: section.symbolName)
                            .tag(section)
                    }
                }
            }
            .navigationTitle("RunJourney")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            NavigationStack {
                switch selectedSection ?? .map {
                case .map:
                    RaceMapView()
                case .dashboard:
                    DashboardView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Race.self, RaceResult.self], inMemory: true)
}
