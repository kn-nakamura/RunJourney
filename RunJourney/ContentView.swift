import SwiftUI
import SwiftData

/// アプリのルート。
/// - iPhone (compact): TabView で 「地図 / ダッシュボード / ペース / 設定」 を切替
/// - iPad / Mac (regular): NavigationSplitView の sidebar から切替
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedSection: AppSection = .map

    enum AppSection: String, Hashable, CaseIterable, Identifiable {
        case map
        case dashboard
        case pace
        case tools
        case settings

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .map: return "MAP"
            case .dashboard: return "DASHBOARD"
            case .pace: return "PACE"
            case .tools: return "TOOLS"
            case .settings: return "SETTINGS"
            }
        }
        var symbolName: String {
            switch self {
            case .map: return "map"
            case .dashboard: return "chart.bar"
            case .pace: return "speedometer"
            case .tools: return "function"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
#if os(iOS)
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
        let tv = TabView(selection: $selectedSection) {
            Tab(AppSection.map.displayName, systemImage: AppSection.map.symbolName, value: AppSection.map) {
                NavigationStack { RaceMapView() }
            }
            Tab(AppSection.dashboard.displayName, systemImage: AppSection.dashboard.symbolName, value: AppSection.dashboard) {
                NavigationStack { DashboardView() }
            }
            Tab(AppSection.pace.displayName, systemImage: AppSection.pace.symbolName, value: AppSection.pace) {
                NavigationStack { PaceCalculatorView() }
            }
            Tab(AppSection.tools.displayName, systemImage: AppSection.tools.symbolName, value: AppSection.tools) {
                NavigationStack { ToolsView() }
            }
            Tab(AppSection.settings.displayName, systemImage: AppSection.settings.symbolName, value: AppSection.settings) {
                NavigationStack { SettingsView() }
            }
        }
#if os(iOS)
        return tv
            .tabBarMinimizeBehavior(.never)         // iOS 26 の自動最小化を無効化
            // TabBar はシステム既定のブラー透過にして、地図画面が下まで広がるようにする。
            // (Web 版 marathon-record-app の viewport いっぱいの地図体験を再現する目的)
#else
        return tv
#endif
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
                case .map:       RaceMapView()
                case .dashboard: DashboardView()
                case .pace:      PaceCalculatorView()
                case .tools:     ToolsView()
                case .settings:  SettingsView()
                }
            }
        }
    }

    private var sidebarSelectionBinding: Binding<AppSection?> {
        Binding(
            get: { selectedSection },
            set: { selectedSection = $0 ?? .map }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Race.self, RaceResult.self, PacePlan.self], inMemory: true)
}
