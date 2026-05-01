import SwiftUI
import SwiftData

/// アプリのルート。
/// - iPhone (compact): TabView で 「地図 / ダッシュボード」 を切替
/// - iPad / Mac (regular): NavigationSplitView の sidebar から切替
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedSection: AppSection = .map

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
        // iPad / iPhone Plus/Max の Landscape のみ Sidebar、それ以外は TabView
        if horizontalSizeClass == .regular {
            sidebarSplitView
        } else {
            tabView
        }
#else
        sidebarSplitView
#endif
    }

    // MARK: - iPhone

    private var tabView: some View {
        TabView(selection: $selectedSection) {
            Tab(AppSection.map.displayName, systemImage: AppSection.map.symbolName, value: AppSection.map) {
                NavigationStack {
                    RaceMapView()
                }
            }
            Tab(AppSection.dashboard.displayName, systemImage: AppSection.dashboard.symbolName, value: AppSection.dashboard) {
                NavigationStack {
                    DashboardView()
                }
            }
        }
        .tabBarMinimizeBehavior(.never)         // iOS 26 の自動最小化を無効化
        .toolbarBackground(.visible, for: .tabBar)
    }

    // MARK: - iPad / Mac

    private var sidebarSplitView: some View {
        NavigationSplitView {
            List(selection: sidebarSelectionBinding) {
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
                switch selectedSection {
                case .map:
                    RaceMapView()
                case .dashboard:
                    DashboardView()
                }
            }
        }
    }

    /// List(selection:) は Optional binding を要求するので bridge する。
    private var sidebarSelectionBinding: Binding<AppSection?> {
        Binding(
            get: { selectedSection },
            set: { selectedSection = $0 ?? .map }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Race.self, RaceResult.self], inMemory: true)
}
