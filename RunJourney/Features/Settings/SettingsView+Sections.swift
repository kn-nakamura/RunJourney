import SwiftUI
import SwiftData

// SettingsView の各セクションを computed property として並べる拡張。
// メイン側 (SettingsView.swift) は状態定義と body / 多カラムディスパッチに集中させ、
// ここはレイアウト/見た目のみを担当する分担にする。

// MARK: - Premium / Tip Jar
//
// 未加入なら蛍光イエローの "Upgrade" ボタン、加入済みなら "Premium Active"
// バッジと Manage (Tip Jar 動線) を出す。

extension SettingsView {
    var premiumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "RunJourney Premium")
            Button {
                Haptics.selection()
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: purchases.hasPremium ? "checkmark.seal.fill" : "lock.open.fill")
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(purchases.hasPremium ? "Premium Active" : "Upgrade to Premium")
                            .appText(.bodyBase)
                            .foregroundStyle(Color.textPrimary)
                        Text(purchases.hasPremium
                             ? "Unlimited races and results, plus PDF / image attachments."
                             : "Unlock unlimited races, results, and PDF / image attachments.")
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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.bgSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(purchases.hasPremium ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Developer
    //
    // 旧 Map 画面の「+ Add Sample」を About の下に控えめに移設したもの。

    var developerSection: some View {
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
                if added > 0 { Haptics.success() } else { Haptics.warning() }
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

    var librarySection: some View {
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

    func statRow(symbol: String, label: String, count: Int, color: Color) -> some View {
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

    var distanceUnitSection: some View {
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

    var customDistanceSection: some View {
        let unit = DistanceUnit.resolve(distanceUnitRaw)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Custom Distance")
            CustomDistanceField(customDistanceKm: $customDistanceKm, unit: unit)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("Save a frequently-used distance to recall it via the Custom button across pace tools.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Heart Rate
    //
    // ゾーン分析 (Z1〜Z5) の基準となる最大心拍。0 のときレース詳細の HR Zone セクション
    // を非表示にする (= 自動推定はしない)。100〜220 の Stepper で手動設定。

    var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Heart Rate")
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.catFullMarathon)
                    .frame(width: 24)
                Text("Max HR")
                    .appText(.bodyBase)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
#if os(iOS)
                TextField("0", text: $maxHRText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.appFont(.codeBaseBold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 56)
                    .focused($maxHRFieldFocused)
                    .onAppear { maxHRText = userMaxHR > 0 ? "\(userMaxHR)" : "" }
                    .onChange(of: userMaxHR) { _, newValue in
                        if !maxHRFieldFocused {
                            maxHRText = newValue > 0 ? "\(newValue)" : ""
                        }
                    }
                    .onChange(of: maxHRFieldFocused) { _, isFocused in
                        if !isFocused { commitMaxHR() }
                    }
                    .onSubmit { commitMaxHR() }
#else
                TextField("0", text: $maxHRText)
                    .multilineTextAlignment(.trailing)
                    .font(.appFont(.codeBaseBold))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 56)
                    .onAppear { maxHRText = userMaxHR > 0 ? "\(userMaxHR)" : "" }
                    .onChange(of: userMaxHR) { _, newValue in
                        maxHRText = newValue > 0 ? "\(newValue)" : ""
                    }
                    .onSubmit { commitMaxHR() }
#endif
                Text("bpm")
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
                Stepper("Max HR", value: $userMaxHR, in: 0...220, step: 1)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("Used for HR Zone analysis (Z1–Z5) on race detail. Set to 0 to hide zone bars.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    func commitMaxHR() {
        let trimmed = maxHRText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            userMaxHR = 0
            maxHRText = ""
            return
        }
        guard let parsed = Int(trimmed) else {
            maxHRText = userMaxHR > 0 ? "\(userMaxHR)" : ""
            return
        }
        let clamped = max(0, min(220, parsed))
        userMaxHR = clamped
        maxHRText = clamped > 0 ? "\(clamped)" : ""
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

    var currentTheme: AppTheme { AppTheme.resolve(appThemeRaw) }

    /// `.system` テーマ時に「実際に効いている」palette テーマ (Dark / Light) を返す。
    /// accent swatch grid と accent binding はこちらを基準に動く。
    var resolvedPaletteTheme: AppTheme {
        switch currentTheme {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return systemColorScheme == .dark ? .dark : .light
        }
    }

    /// 現テーマに対応するアクセント rawValue を読み書きする Binding。
    /// `.system` のときは現在の system colorScheme に合った palette を選ぶ。
    var currentAccentBinding: Binding<String> {
        resolvedPaletteTheme == .dark
            ? Binding(get: { accentDarkRaw },  set: { accentDarkRaw = $0 })
            : Binding(get: { accentLightRaw }, set: { accentLightRaw = $0 })
    }

    var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Appearance")
            VStack(alignment: .leading, spacing: 14) {
                Picker("Theme", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { t in
                        Label(t.label, systemImage: t.symbol).tag(t.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                // `.system` 時は現在の system colorScheme に合った palette を表示。
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

    // MARK: - Language
    //
    // 端末の iOS 言語設定とは独立してアプリ内言語を切替えるためのピッカー。
    // SwiftUI の `Text(LocalizedStringKey)` は `RunJourneyApp` が注入する
    // `.environment(\.locale, …)` で即時切替され、`String(localized:)` 系も
    // `AppleLanguages` UserDefaults 上書きで次の参照から新ロケールを返す。

    var currentLanguage: AppLanguage { AppLanguage.resolve(appLanguageRaw) }

    var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Language")
            Menu {
                Picker("Language", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.availableLanguages()) { lang in
                        Text(lang.label).tag(lang.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: 24)
                    Text("Language")
                        .appText(.bodyBase)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(currentLanguage.label)
                        .appText(.bodySm)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Choose System to follow your iOS language. Some system-managed text may need an app restart to fully update.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Data management
    //
    // 配色は `.secondary` (グレー) で「探さないと見つからない」程度に抑え、
    // 誤タップで4スコープが見えないようにする。タップで `DataManagementSheet` を開く。

    var dataSection: some View {
        Button {
            Haptics.warning()
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

    var iCloudSection: some View {
        let location = StorageLocation(rawValue: storageRaw) ?? .local
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Storage")
            VStack(spacing: 0) {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if location == .iCloud {
                    rowDivider
                    cloudKitStatusRow
                }
            }
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            Text("Switching does not migrate existing data. Each store is independent.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    /// CloudKit アカウント状態の行。`.iCloud` 選択時のみ表示し、タップで再チェック。
    var cloudKitStatusRow: some View {
        let s = cloudKitMonitor.status
        let symbol: String = {
            switch s {
            case .available:                return "checkmark.icloud.fill"
            case .unknown:                  return "icloud"
            case .noAccount, .restricted:   return "exclamationmark.icloud"
            default:                        return "icloud.slash"
            }
        }()
        let tint: Color = s.isHealthy ? Color.accentPrimary : .orange

        return Button {
            Task { await cloudKitMonitor.refresh() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.label)
                        .appText(.bodyBase)
                        .foregroundStyle(Color.textPrimary)
                    Text(s.detail)
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - About

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About")
            VStack(spacing: 0) {
                aboutRow(label: "Version", value: Bundle.main.appVersion)
                rowDivider
                aboutRow(label: "Build", value: Bundle.main.buildNumber)
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

    func aboutRow(label: String, value: String) -> some View {
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

    var rowDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }
}
