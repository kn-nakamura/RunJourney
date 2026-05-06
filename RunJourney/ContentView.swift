import SwiftUI
import SwiftData

/// アプリのルート。
/// - iPhone (compact h, regular v): TabView で 「地図 / ダッシュボード / ペース / ツール / 設定」 を切替
/// - iPhone landscape (compact h, compact v): TabView を維持しつつ各画面側で横向きを活かしたレイアウトに分岐
/// - iPad 縦 / iPad 横 / Mac (regular h): NavigationSplitView の sidebar から切替。
///   ただし iPad 縦 (`padPortrait`) は detail 幅が狭いので、各画面はマルチカラム化を抑え
///   単段スクロールに戻す (`AdaptiveLayout.prefersMultiColumn` が false を返す)。
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var selectedSection: AppSection = .map
    /// iPad / Mac の sidebar 表示状態。横画面では普段は出しっぱなしにしたいので `.all` を初期値にする。
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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

    private func resolvedLayout(containerWidth: CGFloat?) -> AdaptiveLayout {
        AdaptiveLayout.resolve(
            horizontal: horizontalSizeClass,
            vertical: verticalSizeClass,
            containerWidth: containerWidth
        )
    }

    var body: some View {
        // iPad は縦/横どちらも h:regular で SizeClass だけだと見分けがつかないため、
        // ルートで GeometryReader を噛ませてウィンドウ実幅を AdaptiveLayout.resolve() に
        // 渡す (= `padPortrait` の判定根拠)。GeometryReader はここでだけ使い、
        // 子孫はすべて `\.adaptiveLayout` 経由で参照する。
        GeometryReader { proxy in
            let layout = resolvedLayout(containerWidth: proxy.size.width)
            Group {
                if layout.usesSidebarRoot {
                    sidebarSplitView
                } else {
                    tabView
                }
            }
            .environment(\.adaptiveLayout, layout)
        }
    }

    // MARK: - iPhone (portrait & landscape)

    private var tabView: some View {
        let binding = Binding<AppSection>(
            get: { selectedSection },
            set: { newValue in
                if newValue != selectedSection {
                    Haptics.tap()
                }
                selectedSection = newValue
            }
        )
        let tv = TabView(selection: binding) {
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: sidebarSelectionBinding) {
                Section("RunJourney") {
                    ForEach(AppSection.allCases) { section in
                        Label(section.displayName, systemImage: section.symbolName)
                            .tag(section)
                    }
                }
            }
            .navigationTitle("RunJourney")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            NavigationStack {
                Group {
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
        .navigationSplitViewStyle(.balanced)
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
