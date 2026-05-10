import SwiftUI
import SwiftData

/// アプリのタブ / sidebar セクション。
/// テーマやアクセント色の変更で view tree を再構築しても保持したいため、
/// `AppNavigationStore` 経由で App-level の `@State` に格納する。
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

/// 画面遷移状態をテーマ/アクセント切替の view 再構築の外側に保持するためのストア。
/// `RunJourneyApp` の `@State` で 1 インスタンス作り、environment 経由で各 View に渡す。
@Observable
final class AppNavigationStore {
    var selectedSection: AppSection = .map
    var columnVisibility: NavigationSplitViewVisibility = .all
    var presentedDetailRace: Race? = nil
}

extension EnvironmentValues {
    @Entry var appNavigation: AppNavigationStore = AppNavigationStore()
}

/// アプリのルート。
/// - iPhone (compact h, regular v): TabView で 「地図 / ダッシュボード / ペース / ツール / 設定」 を切替
/// - iPhone landscape (compact h, compact v): TabView を維持しつつ各画面側で横向きを活かしたレイアウトに分岐
/// - iPad 縦 / iPad 横 / Mac (regular h): NavigationSplitView の sidebar から切替。
///   ただし iPad 縦 (`padPortrait`) は detail 幅が狭いので、各画面はマルチカラム化を抑え
///   単段スクロールに戻す (`AdaptiveLayout.prefersMultiColumn` が false を返す)。
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.appNavigation) private var nav

    private var selectedSection: AppSection {
        get { nav.selectedSection }
        nonmutating set { nav.selectedSection = newValue }
    }
    private var columnVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(get: { nav.columnVisibility }, set: { nav.columnVisibility = $0 })
    }
    private var presentedDetailRaceBinding: Binding<Race?> {
        Binding(get: { nav.presentedDetailRace }, set: { nav.presentedDetailRace = $0 })
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
            ZStack(alignment: .topLeading) {
                Group {
                    if layout.usesSidebarRoot {
                        sidebarSplitView
                    } else {
                        tabView
                    }
                }

                // iPad 横/縦で詳細オーバーレイを ContentView ルートで描画。下から引き上がる。
                // - 横 (isWide): 画面の左半分を占める縦長パネル
                // - 縦 (padPortrait): 画面の下半分を占める横長パネル (iPhone の bottom sheet と
                //   同じ視覚スタイル。`.sheet` の iPad form sheet 適応を回避するため自前で出す)
                // 外側 sidebar / RACES ドロワー / 地図は静止したまま、このパネルだけが動く。
                if let race = nav.presentedDetailRace {
                    if layout.isWide {
                        detailOverlay(race: race)
                            .frame(width: proxy.size.width / 2)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .bottom))
                            .zIndex(100)
                    } else if layout == .padPortrait {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            detailOverlay(race: race)
                                .frame(maxWidth: .infinity)
                                .frame(height: proxy.size.height * 0.65)
                                .clipShape(.rect(topLeadingRadius: 28, topTrailingRadius: 28))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                        .zIndex(100)
                    }
                }
            }
            // adaptiveLayout は ZStack 全体にかける。detailOverlay 内の RaceResultDetailView が
            // `usesSidebarRoot` を見てフライスルーを `.fullScreenCover` で全画面表示するために必要。
            .environment(\.adaptiveLayout, layout)
            .animation(.easeInOut(duration: 0.3), value: nav.presentedDetailRace == nil)
        }
    }

    /// iPad 横で画面の左半分に重ねる「下から引き上がる」レース詳細オーバーレイ。
    /// ContentView ルートで描画することで NavigationSplitView の外側 sidebar も
    /// 含めて覆える。Close で binding を nil に戻すと下へスライドして消える。
    @ViewBuilder
    private func detailOverlay(race: Race) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    Haptics.tap()
                    nav.presentedDetailRace = nil
                } label: {
                    Text("Close")
                        .appText(.bodyBaseBold)
                        .foregroundStyle(Color.accentPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Race Detail")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            NavigationStack {
                RaceSummaryView(race: race)
            }
        }
        .background(Color.bgPrimary)
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
                NavigationStack { RaceMapView(sheetRace: presentedDetailRaceBinding) }
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
        NavigationSplitView(columnVisibility: columnVisibilityBinding) {
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
                    case .map:       RaceMapView(sheetRace: presentedDetailRaceBinding)
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
