import SwiftUI
import SwiftData

/// アプリ設定・データ管理画面。
/// Dashboard / Pace と同じ ScrollView + VStack 構造で、L2 中タイトルに `SectionHeader`
/// (Bebas Neue 24pt) を使う。Form ではなく独自レイアウトなので、行は角丸ダーク背景の
/// カード (`Color.bgSecondary` + RoundedRectangle 12pt) でくるむ。
///
/// 各セクションのレイアウトは `SettingsView+Sections.swift` に分離している。
struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Query var races: [Race]
    @Query var results: [RaceResult]
    @Query var plans: [PacePlan]

    @AppStorage(StorageLocation.userDefaultsKey) var storageRaw: String = StorageLocation.local.rawValue
    @AppStorage(StorageLocation.chosenFlagKey) var hasChosen: Bool = false

    /// アプリ全体の距離単位 (km / mi)。Pace / Map / Dashboard / Playback など全表示に反映。
    @AppStorage("distanceUnit") var distanceUnitRaw: String = DistanceUnit.km.rawValue
    /// よく使う距離 (km 内部値)。PaceCalculatorView の Custom チップと共有。
    @AppStorage("customDistanceKm") var customDistanceKm: Double = 10.0

    /// HR ゾーン分析 (Z1〜Z5) で使う最大心拍。0 のときは未設定としてゾーン表示を抑止する。
    @AppStorage("userMaxHR") var userMaxHR: Int = 0
    @State var maxHRText: String = ""
    @FocusState var maxHRFieldFocused: Bool

    /// アプリ全体のテーマ (Dark / Light)。マップも追従する。
    @AppStorage(AppTheme.userDefaultsKey) var appThemeRaw: String = AppTheme.dark.rawValue
    /// アプリ内言語 (System / English / Japanese)。端末設定とは独立して切替可能。
    @AppStorage(AppLanguage.userDefaultsKey) var appLanguageRaw: String = AppLanguage.system.rawValue
    /// テーマ毎のアクセント色選択 (蛍光イエロー等)。テーマ切替後も独立復元。
    @AppStorage(AccentChoice.storageKeyDark)  var accentDarkRaw: String  = AccentChoice.neonYellow.rawValue
    @AppStorage(AccentChoice.storageKeyLight) var accentLightRaw: String = AccentChoice.sunYellow.rawValue

    /// `.system` テーマ時に accent swatch grid をどちらの palette で描くかを決めるため、
    /// 現在実際に適用されている system colorScheme を読み取る。
    @Environment(\.colorScheme) var systemColorScheme

    @State var showDataSheet = false
    @State var showDataTransferSheet = false
    @State var showStorageSwitchAlert = false
    @State var sampleLoadMessage: String?

    /// iCloud アカウントの可用性をリアルタイム表示するためのモニタ。
    /// `.iCloud` ストレージを選んでいる時のみ意味を持つが、初期化は常に行ってもコスト極小。
    @State var cloudKitMonitor = CloudKitAccountMonitor()

    /// アプリ起動時に注入される PurchaseManager。Premium バッジ + Paywall sheet の駆動。
    @Environment(PurchaseManager.self) var purchases

    /// 端末サイズに応じた多カラム表示切替。`ContentView` で注入される。
    @Environment(\.adaptiveLayout) var layout

    @State var showPaywall = false

    enum DeleteScope: String, CaseIterable, Identifiable {
        case results
        case races
        case plans
        case everything

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .results: return "Results Only"
            case .races: return "Races & Results"
            case .plans: return "Pace Plans Only"
            case .everything: return "Everything"
            }
        }
        var summary: String {
            switch self {
            case .results: return String(localized: "Deletes all registered results (times, routes). Race entries are kept.")
            case .races: return String(localized: "Deletes race entries and all linked results.")
            case .plans: return String(localized: "Deletes all saved pace plans.")
            case .everything: return String(localized: "Deletes everything (races, results, pace plans). Cannot be undone.")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .appText(layout.isVerticallyCompact ? .displayMd : .displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if layout.prefersMultiColumn {
                    multiColumnSections
                } else {
                    singleColumnSections
                }
            }
            .padding(layout.standardPadding)
            .frame(maxWidth: layout.contentMaxWidth ?? .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
#endif
        .keyboardCloseToolbar()
        .dismissKeyboardOnBackgroundTap()
        .task {
            cloudKitMonitor.startObserving()
            await cloudKitMonitor.refresh()
        }
        .sheet(isPresented: $showDataSheet) {
            DataManagementSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDataTransferSheet) {
            DataTransferSheet()
                .presentationDetents([.medium, .large])
        }
        .alert("Choose storage on next launch?", isPresented: $showStorageSwitchAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Re-choose on Relaunch") {
                hasChosen = false
            }
        } message: {
            Text("Switching does not migrate existing data. Quit and reopen RunJourney to pick a new storage location.")
        }
        .alert("Sample Data", isPresented: Binding(
            get: { sampleLoadMessage != nil },
            set: { if !$0 { sampleLoadMessage = nil } }
        ), presenting: sampleLoadMessage) { _ in
            Button("OK") { sampleLoadMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(reason: nil)
        }
    }

    // MARK: - Section dispatch (single vs multi-column)

    /// 縦持ち iPhone 用: 既存の縦並び。各セクションは flex 横幅。
    @ViewBuilder
    private var singleColumnSections: some View {
        premiumSection
        librarySection
        distanceUnitSection
        customDistanceSection
        heartRateSection
        appearanceSection
        languageSection
        iCloudSection
        aboutSection
        developerSection
        dataSection
    }

    /// 横向き iPhone / iPad / Mac 用: 設定をカテゴリごとの 2 カラムに分け、
    /// 「ライブラリ・アカウント系」と「アプリ動作・外観系」を並列に見られるようにする。
    /// 上端には Premium / Library を全幅で残し、下に dataSection を控えめに置く。
    @ViewBuilder
    private var multiColumnSections: some View {
        premiumSection
        librarySection
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                distanceUnitSection
                customDistanceSection
                heartRateSection
                iCloudSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 20) {
                appearanceSection
                languageSection
                aboutSection
                developerSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        dataSection
    }
}
