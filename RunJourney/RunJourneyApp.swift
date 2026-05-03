import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct RunJourneyApp: App {

    @AppStorage(StorageLocation.chosenFlagKey) private var hasChosen: Bool = false
    @AppStorage(StorageLocation.userDefaultsKey) private var storageRaw: String = StorageLocation.local.rawValue

    @State private var splashCoordinator = SplashCoordinator()
    @State private var modelContainer: ModelContainer?

    init() {
#if os(iOS)
        AppUIKitAppearance.configureAll()
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasChosen {
                    StorageLocationPickerView { selection in
                        storageRaw = selection.rawValue
                        modelContainer = Self.makeContainer(for: selection)
                        hasChosen = true
                    }
                } else if let container = modelContainer {
                    ZStack {
                        ContentView()
                        if splashCoordinator.phase != .done {
                            SplashView()
                                .transition(.opacity)
                        }
                    }
                    .environment(splashCoordinator)
                    .modelContainer(container)
                } else {
                    Color.bgPrimary
                        .ignoresSafeArea()
                        .task {
                            let location = StorageLocation(rawValue: storageRaw) ?? .local
                            modelContainer = Self.makeContainer(for: location)
                        }
                }
            }
            .preferredColorScheme(.dark)
            .tint(.accentPrimary)
            .background(Color.bgPrimary)
        }
    }

    /// 選んだ保存先に応じて ModelContainer を構築する。
    /// iCloud を選ぶと SwiftData が CloudKit private DB をミラーリングする。
    /// （Apple Developer Program 加入＋ CloudKit コンテナ作成は前提作業）
    static func makeContainer(for location: StorageLocation) -> ModelContainer {
        let schema = Schema([
            Race.self,
            RaceResult.self,
            PacePlan.self,
            Attachment.self,
        ])
        let configuration: ModelConfiguration
        switch location {
        case .local:
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        case .iCloud:
            guard Self.hasCloudKitEntitlement() else {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return (try? ModelContainer(for: schema, configurations: [fallback]))
                    ?? { fatalError("Could not create local ModelContainer") }()
            }
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.kn-nakamura.RunJourney")
            )
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // CloudKit 設定が portal 側で未完だと iCloud モードは失敗するので、
            // local にフォールバックして起動を続ける（次回起動で改めて選び直せる）。
            if location == .iCloud {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return (try? ModelContainer(for: schema, configurations: [fallback])) ?? {
                    fatalError("Could not create ModelContainer: \(error)")
                }()
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private static func hasCloudKitEntitlement() -> Bool {
        // embedded.mobileprovision exists only in dev/TestFlight builds on device.
        // Simulator and App Store builds have no file → assume entitlements are valid.
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return true }
        return data.range(of: Data("CloudKit".utf8)) != nil
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
