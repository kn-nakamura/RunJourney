import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct RunJourneyApp: App {

    @State private var splashCoordinator = SplashCoordinator()

    init() {
#if os(iOS)
        AppUIKitAppearance.configureAll()
#endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Race.self,
            RaceResult.self,
            PacePlan.self,
        ])
        // MVP初期はローカルのみ。Apple Developer Program加入後に
        // ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.kn-nakamura.RunJourney"))
        // へ切り替えてiCloud同期を有効化する。
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if splashCoordinator.phase != .done {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .environment(splashCoordinator)
            .preferredColorScheme(.dark)        // Webアプリと同じダークテーマ固定
            .tint(.accentPrimary)               // 蛍光イエローグリーン (#E8FF47)
            .background(Color.bgPrimary)
        }
        .modelContainer(sharedModelContainer)
    }
}

#if os(iOS)
/// アプリ全体の UIKit Appearance を Bebas Neue + tracking + UPPERCASE で揃える。
/// SwiftUI の `.appText(_:)` modifier はビュー単位だが、TabBar / Navigation Bar の
/// システム描画部分は UIKit が直接担当するため、ここで書体を差し込む必要がある。
///
/// SwiftUI `ToolbarItem(.principal)` 経由だと Navigation Bar が内部で
/// `.bold()` を被せて synthetic bold になり、Bebas Neue が別書体に見える事故が
/// 起きるため、Navigation Bar も UIKit Appearance で直接書体を差し込む。
enum AppUIKitAppearance {

    /// アプリ起動時に1度呼ぶ。SwiftUI ライフサイクルで Navigation/Tab Bar が初期化される前に
    /// `UI*.appearance()` プロキシへ書き込む必要があるため、`@main` の init から早期に呼ぶ。
    static func configureAll() {
        configureNavigationBar()
        configureTabBar()
    }

    /// MAP タブのように `.ignoresSafeArea` でフルスクリーンになる画面では iOS 26 が
    /// scrollEdge / minimized 系のアピアランスへ勝手に切り替えてしまうため、
    /// 該当画面の `.onAppear` から呼んで明示的に書体を再注入する。
    static func reapplyTabBar() {
        configureTabBar()
    }

    private static func configureNavigationBar() {
        guard let navTitleFont = UIFont(name: "BebasNeue-Regular", size: 22) else { return }
        let navAttrs: [NSAttributedString.Key: Any] = [
            .font: navTitleFont,
            .kern: 1.4,
            .foregroundColor: UIColor.label,
        ]
        let largeNavAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "BebasNeue-Regular", size: 32) ?? navTitleFont,
            .kern: 1.6,
            .foregroundColor: UIColor.label,
        ]
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.titleTextAttributes = navAttrs
        navAppearance.largeTitleTextAttributes = largeNavAttrs
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
    }

    private static func configureTabBar() {
        // iOS 26 Liquid Glass のタブバーは UIAppearance を取りこぼすことがあるため、
        // 多重に書体を流し込む:
        //   1. UITabBarAppearance: 全レイアウト × 全状態 (normal/selected/disabled/focused)
        //   2. UITabBarItem.appearance(): 旧 API のフォールバック
        //   3. UILabel.appearance(whenContainedInInstancesOf:): タブバー内ラベル直撃の最終手段
        guard let tabFont = UIFont(name: "BebasNeue-Regular", size: 11) else { return }
        let tabAttrs: [NSAttributedString.Key: Any] = [
            .font: tabFont,
            .kern: 1.2,
        ]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        let layouts: [UITabBarItemAppearance] = [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance,
        ]
        for layout in layouts {
            layout.normal.titleTextAttributes = tabAttrs
            layout.selected.titleTextAttributes = tabAttrs
            layout.disabled.titleTextAttributes = tabAttrs
            layout.focused.titleTextAttributes = tabAttrs
        }
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        UITabBarItem.appearance().setTitleTextAttributes(tabAttrs, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(tabAttrs, for: .selected)
        UITabBarItem.appearance().setTitleTextAttributes(tabAttrs, for: .disabled)
        UITabBarItem.appearance().setTitleTextAttributes(tabAttrs, for: .focused)
        UITabBarItem.appearance().setTitleTextAttributes(tabAttrs, for: .highlighted)

        // タブバー内のすべての UILabel に Bebas Neue を直接当てる（最終手段）。
        // iOS 26 が UITabBarItem の titleTextAttributes を無視するケースで効く。
        UILabel.appearance(whenContainedInInstancesOf: [UITabBar.self]).font = tabFont
    }
}
#endif
