import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct RunJourneyApp: App {

    @AppStorage(StorageLocation.chosenFlagKey) private var hasChosen: Bool = false
    @AppStorage(StorageLocation.userDefaultsKey) private var storageRaw: String = StorageLocation.local.rawValue

    /// アプリ全体のテーマ。Settings → Appearance で切替。
    @AppStorage(AppTheme.userDefaultsKey) private var appThemeRaw: String = AppTheme.dark.rawValue
    /// テーマ毎のアクセント色選択。テーマ切替後も各テーマで前回選んだ色が復元される。
    @AppStorage(AccentChoice.storageKeyDark)  private var accentDarkRaw: String  = AccentChoice.neonYellow.rawValue
    @AppStorage(AccentChoice.storageKeyLight) private var accentLightRaw: String = AccentChoice.sunYellow.rawValue
    /// アプリ内言語。Settings → Language で切替。`.system` 以外は端末設定と独立して固定する。
    @AppStorage(AppLanguage.userDefaultsKey) private var appLanguageRaw: String = AppLanguage.system.rawValue

    @State private var splashCoordinator = SplashCoordinator()
    @State private var modelContainer: ModelContainer?
    /// アプリ起動時に 1 回だけ作る StoreKit 2 ラッパ。
    /// `Transaction.updates` の購読をプロセス生存中ずっと回す必要があるため、
    /// scene 切替で破棄されないようにここに置く。
    @State private var purchaseManager = PurchaseManager()
    /// テーマ/アクセント変更で view tree が rebuild されてもナビゲーション状態を保持するための
    /// 共有ストア。App-level `@State` はプロセス生存中保持されるため `.id(...)` の影響を受けない。
    @State private var navStore = AppNavigationStore()

    init() {
        // SwiftUI 構築前に AppleLanguages を反映しておくことで、起動直後の Bundle.main 参照
        // (= `String(localized:)`) が選択言語で解決されるようにする。
        AppLanguage.applyToSystem(AppLanguage.resolve(
            UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey) ?? AppLanguage.system.rawValue
        ))
#if os(iOS)
        AppUIKitAppearance.configureAll()
#endif
    }

    private var currentTheme: AppTheme { AppTheme.resolve(appThemeRaw) }
    private var currentLanguage: AppLanguage { AppLanguage.resolve(appLanguageRaw) }

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
                    .environment(purchaseManager)
                    .modelContainer(container)
                    .task { await purchaseManager.loadProducts() }
                } else {
                    Color.bgPrimary
                        .ignoresSafeArea()
                        .task {
                            let location = StorageLocation(rawValue: storageRaw) ?? .local
                            modelContainer = Self.makeContainer(for: location)
                        }
                }
            }
            // アクセントだけ変えても trait は変わらないため、`UIColor(dynamicProvider:)`
            // は再評価されない。`.id(...)` でツリーを強制再構築し全 Color を再解決する。
            // 言語切替も同様に Locale 環境を全 Text に再解決させたいので id に含める。
            // ※ ナビゲーション状態 (selectedSection 等) は AppNavigationStore (App-level @State)
            //    に持たせて、この rebuild で消えないようにしている。
            .id("\(appThemeRaw)|\(accentDarkRaw)|\(accentLightRaw)|\(appLanguageRaw)")
            .environment(\.appNavigation, navStore)
            .preferredColorScheme(currentTheme.colorScheme)
            .environment(\.locale, currentLanguage.localeIdentifier.map { Locale(identifier: $0) } ?? Locale.current)
            .tint(.accentPrimary)
            .background(Color.bgPrimary)
#if os(iOS)
            .onChange(of: appThemeRaw) { _, _ in
                // Nav/Tab Bar の UIKit Appearance は launch 時の trait を捕まえるだけなので
                // テーマ切替に追従しない。明示的に再注入する。
                AppUIKitAppearance.refreshForTheme()
            }
            .onChange(of: appLanguageRaw) { _, newValue in
                // SwiftUI Text(LocalizedStringKey) は environment(\.locale) で即時切替されるが、
                // `String(localized:)` 等 Bundle.main 経由の参照のため AppleLanguages も更新する。
                AppLanguage.applyToSystem(AppLanguage.resolve(newValue))
            }
#endif
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

    /// テーマ切替 (Dark↔Light) 時に Nav/TabBar の `configureWithDefaultBackground()` が
    /// 拾う背景トーンを更新する。アピアランスは proxy への再 set だけでは既存の
    /// view controller には反映されないため、現在表示中の bar も walk して直接更新する。
    static func refreshForTheme() {
        configureNavigationBar()
        configureTabBar()

        // 既存の window scenes を walk して、表示中の Nav/TabBar に新しいアピアランスを上書きする。
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                refreshBars(in: window.rootViewController)
            }
        }
    }

    private static func refreshBars(in vc: UIViewController?) {
        guard let vc else { return }
        if let nav = vc as? UINavigationController {
            nav.navigationBar.standardAppearance     = UINavigationBar.appearance().standardAppearance
            nav.navigationBar.scrollEdgeAppearance   = UINavigationBar.appearance().scrollEdgeAppearance
            nav.navigationBar.compactAppearance      = UINavigationBar.appearance().compactAppearance
            nav.navigationBar.compactScrollEdgeAppearance = UINavigationBar.appearance().compactScrollEdgeAppearance
        }
        if let tab = vc as? UITabBarController {
            tab.tabBar.standardAppearance   = UITabBar.appearance().standardAppearance
            tab.tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance
        }
        for child in vc.children {
            refreshBars(in: child)
        }
        refreshBars(in: vc.presentedViewController)
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
