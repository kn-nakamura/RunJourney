import SwiftUI
import SwiftData

/// アプリ設定・データ管理画面。
/// Dashboard / Pace と同じ ScrollView + VStack 構造で、L2 中タイトルに `SectionHeader`
/// (Bebas Neue 24pt) を使う。Form ではなく独自レイアウトなので、行は角丸ダーク背景の
/// カード (`Color.bgSecondary` + RoundedRectangle 12pt) でくるむ。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var races: [Race]
    @Query private var results: [RaceResult]
    @Query private var plans: [PacePlan]

    @AppStorage(StorageLocation.userDefaultsKey) private var storageRaw: String = StorageLocation.local.rawValue
    @AppStorage(StorageLocation.chosenFlagKey) private var hasChosen: Bool = false

    /// アプリ全体の距離単位 (km / mi)。Pace / Map / Dashboard / Playback など全表示に反映。
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    /// よく使う距離 (km 内部値)。PaceCalculatorView の Custom チップと共有。
    @AppStorage("customDistanceKm") private var customDistanceKm: Double = 10.0
    @State private var customDistanceText: String = ""

    /// アプリ全体のテーマ (Dark / Light)。マップも追従する。
    @AppStorage(AppTheme.userDefaultsKey) private var appThemeRaw: String = AppTheme.dark.rawValue
    /// テーマ毎のアクセント色選択 (蛍光イエロー等)。テーマ切替後も独立復元。
    @AppStorage(AccentChoice.storageKeyDark)  private var accentDarkRaw: String  = AccentChoice.neonYellow.rawValue
    @AppStorage(AccentChoice.storageKeyLight) private var accentLightRaw: String = AccentChoice.sunYellow.rawValue

    /// `.system` テーマ時に accent swatch grid をどちらの palette で描くかを決めるため、
    /// 現在実際に適用されている system colorScheme を読み取る。
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var showDataSheet = false
    @State private var showStorageSwitchAlert = false
    @State private var sampleLoadMessage: String?

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
            case .results: return "Deletes all registered results (times, routes). Race entries are kept."
            case .races: return "Deletes race entries and all linked results."
            case .plans: return "Deletes all saved pace plans."
            case .everything: return "Deletes everything (races, results, pace plans). Cannot be undone."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .appText(.displayLg)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                librarySection
                distanceUnitSection
                customDistanceSection
                appearanceSection
                iCloudSection
                aboutSection
                developerSection
                dataSection
            }
            .padding()
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .sheet(isPresented: $showDataSheet) {
            DataManagementSheet()
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
    }

    // MARK: - Developer (sample data)
    //
    // 旧 Map 画面の「+ Add Sample」を移設。プロダクションでは目立たない位置 (About の下)
    // に置き、開発・デモ用途として明示する。

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Developer")
            Button {
                let added = RaceSampleLoader.loadJapanSamples(
                    into: modelContext,
                    existing: races
                )
                sampleLoadMessage = added > 0
                    ? "Added \(added) sample race\(added == 1 ? "" : "s")."
                    : "All sample races are already loaded."
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Load Sample Races (Japan)")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text("Adds 8 demo races across Japan. Skips duplicates.")
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Library")
            VStack(spacing: 0) {
                statRow(symbol: "flag.checkered", label: "Races", count: races.count, color: .accentPrimary)
                rowDivider
                statRow(symbol: "figure.run", label: "Results", count: results.count, color: .cat10K)
                rowDivider
                statRow(symbol: "bookmark.fill", label: "Pace Plans", count: plans.count, color: .catHalfMarathon)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statRow(symbol: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .appText(.bodyBase)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("\(count)")
                .appText(.codeBaseBold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Distance Unit (app-wide)

    private var distanceUnitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Distance Unit")
            Picker("Distance Unit", selection: $distanceUnitRaw) {
                Text("km").tag(DistanceUnit.km.rawValue)
                Text("Miles").tag(DistanceUnit.mi.rawValue)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Custom Distance (shared via @AppStorage("customDistanceKm"))

    private var customDistanceSection: some View {
        let unit = DistanceUnit.resolve(distanceUnitRaw)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Custom Distance")
            HStack(spacing: 8) {
#if os(iOS)
                TextField(unit.label, text: $customDistanceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.appFont(.codeBaseBold))
                    .onAppear { customDistanceText = formatCustomDistance(unit: unit) }
                    .onChange(of: distanceUnitRaw) { _, _ in
                        customDistanceText = formatCustomDistance(unit: DistanceUnit.resolve(distanceUnitRaw))
                    }
                    .onSubmit { commitCustomDistance(unit: unit) }
#else
                TextField(unit.label, text: $customDistanceText)
                    .multilineTextAlignment(.trailing)
                    .font(.appFont(.codeBaseBold))
                    .onAppear { customDistanceText = formatCustomDistance(unit: unit) }
                    .onChange(of: distanceUnitRaw) { _, _ in
                        customDistanceText = formatCustomDistance(unit: DistanceUnit.resolve(distanceUnitRaw))
                    }
                    .onSubmit { commitCustomDistance(unit: unit) }
#endif
                Text(unit.label)
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("Save a frequently-used distance to recall it via the Custom button across pace tools.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    private func formatCustomDistance(unit: DistanceUnit) -> String {
        let v = customDistanceKm.displayed(in: unit)
        return abs(v) >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v)
    }

    private func commitCustomDistance(unit: DistanceUnit) {
        let normalized = customDistanceText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(normalized), parsed > 0 else {
            customDistanceText = formatCustomDistance(unit: unit)
            return
        }
        customDistanceKm = parsed.toKm(from: unit)
        customDistanceText = formatCustomDistance(unit: unit)
    }

    // MARK: - Appearance (theme + accent)
    //
    // 設計トーン:
    // - Dark = 夜のネオン (現行ブランド: 蛍光イエロー × ほぼ黒)
    // - Light = 昼の自然光 (パーチメント基調 × 自然素材アクセント)
    //
    // テーマ切替で background / text / border は `UIColor(dynamicProvider:)` 経由で
    // 自動追従。アクセント色だけ trait に紐づかないため、`RunJourneyApp` 側で
    // `.id(...)` を付与して accent 変更時に view tree を再構築している。

    private var currentTheme: AppTheme { AppTheme.resolve(appThemeRaw) }

    /// `.system` テーマ時に「実際に効いている」palette テーマ (Dark / Light) を返す。
    /// それ以外は `currentTheme` をそのまま返す。
    /// accent swatch grid と accent binding はこちらを基準に動く。
    private var resolvedPaletteTheme: AppTheme {
        switch currentTheme {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return systemColorScheme == .dark ? .dark : .light
        }
    }

    /// 現テーマに対応するアクセント rawValue を読み書きする Binding。
    /// `.system` のときは現在の system colorScheme に合った palette を選ぶ。
    private var currentAccentBinding: Binding<String> {
        resolvedPaletteTheme == .dark
            ? Binding(get: { accentDarkRaw },  set: { accentDarkRaw = $0 })
            : Binding(get: { accentLightRaw }, set: { accentLightRaw = $0 })
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Appearance")
            VStack(alignment: .leading, spacing: 14) {
                // Theme picker (Dark / Light / System) — distanceUnit と同じ segmented picker パターン。
                Picker("Theme", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { t in
                        Label(t.label, systemImage: t.symbol).tag(t.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                // Accent swatch grid: 現テーマに対応する色一覧。
                // `.system` のときは現在の system colorScheme に合った palette (dark or light) を表示する。
                // 選択中は textPrimary 色のリングで強調する。
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                    spacing: 12
                ) {
                    ForEach(AccentChoice.options(for: resolvedPaletteTheme)) { choice in
                        Button {
                            currentAccentBinding.wrappedValue = choice.rawValue
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: choice.hex))
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .strokeBorder(
                                        currentAccentBinding.wrappedValue == choice.rawValue
                                            ? Color.textPrimary
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                                    .frame(width: 40, height: 40)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .accessibilityLabel(choice.label)
                            .accessibilityAddTraits(
                                currentAccentBinding.wrappedValue == choice.rawValue
                                    ? .isSelected : []
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))

            Text("Dark suits city neon at night. Light brings natural daylight tones; the map switches with the theme. Choose System to follow your iOS appearance.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Data management
    //
    // 画面最下部に置く控えめな入口。配色は `.secondary` (グレー) で「探さないと見つからない」程度に
    // 抑え、誤タップで4スコープが見えないようにする。タップで `DataManagementSheet` を開き、
    // そこで初めてスコープ選択 → 個別 alert で確定。

    private var dataSection: some View {
        Button {
            showDataSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Delete data...")
                    .appText(.bodyXs)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Storage

    private var iCloudSection: some View {
        let location = StorageLocation(rawValue: storageRaw) ?? .local
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Storage")
            Button {
                showStorageSwitchAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: location.systemImage)
                        .foregroundStyle(Color.cat5K)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.displayName)
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text(location.detail)
                            .appText(.bodyXs)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Switching does not migrate existing data. Each store is independent.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About")
            VStack(spacing: 0) {
                aboutRow(label: "Version", value: appVersion)
                rowDivider
                aboutRow(label: "Build", value: buildNumber)
                rowDivider
                Link(destination: URL(string: "https://github.com/kn-nakamura/run-journey-ios")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: 24)
                        Text("GitHub Repository")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .appText(.bodyBase)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .appText(.codeSm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
