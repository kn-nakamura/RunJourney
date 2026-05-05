import SwiftUI
import SwiftData
import MapKit

/// メインの地図画面。全レースを色分けピンで表示し、タップで詳細を開く。
/// マップ右下の Layers ボタンから `MapStylePanel` を開いてスタイル/ピンをカスタマイズできる。
///
/// 重要: SwiftUI 標準の `Map` ビューは iOS 26 でタブバーアピアランスを内部から壊し、
/// MAP タブだけタブラベル書体がシステムフォントに戻る不具合を起こすため使えない。
/// 地図は `RaceListMapView`（MKMapView を `UIViewRepresentable` で直接ラップ）を使う。
/// この副作用は SwiftUI Map 特有で、MKMapView を介すと発生しない。
struct RaceMapView: View {
    @Environment(SplashCoordinator.self) private var splashCoordinator
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    /// アプリ全体のテーマ。マップは Settings で選んだ Dark/Light に追従する
    /// (旧 `mapSettings.colorMode` は `MapStylePanel` 上で disable 化済み)。
    @AppStorage(AppTheme.userDefaultsKey) private var appThemeRaw: String = AppTheme.dark.rawValue
    private var appTheme: AppTheme { AppTheme.resolve(appThemeRaw) }

    /// 地図に出すレース (lat/lng が未設定の `(0, 0)` レースは除外)。
    /// "+ → Add Race" で作った直後のレースは位置未確定なので、ユーザが
    /// LocationSearchField で住所を確定するまでピンを立てない。
    /// さらに RACES ドロワーと共有する `filters` (search / category / year) でも絞り込む。
    private var mappableRaces: [Race] {
        races.filter { race in
            if race.lat == 0 && race.lng == 0 { return false }
            return filters.matches(race)
        }
    }

    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    /// MKMapView へ渡す「一回限りの region 変更要求」。fit 操作時にセットし、
    /// 反映後は MKMapView 側で nil に戻される。
    @State private var requestedRegion: MKCoordinateRegion?
    /// `requestedRegion` を画面上半分にフィットさせるか。`fitRace` (= ピン1件への
    /// ズーム) のときだけ true。シートが下半分に被さる前提で、ピンを上半分中央に
    /// 置くことでシートに隠れないようにする。
    @State private var requestedRegionUpperHalf = false
    /// MKMapView がタップ検知 → SwiftUI バインディングへ伝える「カメラを動かしたい対象」。
    /// シート表示用の `sheetRace`、ピンの拡大/アイコン化用の `iconifiedRace` と
    /// 3 つに分離することで、ズーム → シート → アイコン化のタイミングを個別制御する。
    @State private var selectedRace: Race?
    @State private var sheetRace: Race?
    /// ピンを「拡大＋アイコン表示」状態にするレース。`sheetRace` の onChange と同期して
    /// セット/解除されるため、シート出現と同じタイミングでピンがアイコンに切替わる。
    @State private var iconifiedRace: Race?
    @State private var zoomTask: Task<Void, Never>?
    @State private var hasFitInitialRaces = false
    @State private var showRaceList = false
    @State private var showMapShareSheet = false
    /// 親→子のズーム指示。`MapZoomCommand` をセットすると `RaceListMapView` が
    /// 一度だけ setRegion を呼び、終わったら nil に戻す。
    @State private var requestedZoom: MapZoomCommand? = nil
    /// 子→親で逐次更新される現在の地図中心。AddRaceSheet 初期地点等に使う。
    @State private var currentMapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
        latitude: 36.5, longitude: 138.0
    )
    /// RACES ドロワーと共有するフィルター。binding でドロワーに渡すことで、
    /// ドロワーでの絞り込みが地図ピンにもそのまま反映される。
    /// category / year が変わったら残った範囲に再フィット (検索文字の毎キーストロークは無視)。
    @State private var filters = RaceFilters()

    /// レース 0 件で起動したときに見せるデフォルト region。日本全体がふんわり収まるサイズ。
    private static let japanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.0),
        span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 13.0)
    )

    var body: some View {
        // 構造のキモ:
        // - ColorSchemeOverride は UIHostingController でラップする副作用で、
        //   その内部の `.ignoresSafeArea` はホスト境界より外に届かない。
        //   そこで ColorSchemeOverride＋mapLayer を ZStack の 1 レイヤーに閉じ、
        //   外側で `.ignoresSafeArea(edges: .top)` をかけて status bar まで広げる。
        // - overlayLayer は ZStack 直下に置き safe area 内に保持。
        //   ハンバーガー / Layers / FAB がステータスバーやタブバーに被らない。
        ZStack {
            ColorSchemeOverride(scheme: appTheme.colorScheme) {
                mapLayer
            }
            .ignoresSafeArea(edges: .top)

            overlayLayer
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .sheet(isPresented: $showMapShareSheet) {
            MapShareSheet(
                races: mappableRaces,
                totalCount: races.filter { !($0.lat == 0 && $0.lng == 0) }.count
            )
        }
        .sheet(isPresented: $showRaceList) {
            RaceListDrawer(
                races: races,
                filters: $filters,
                onSelect: { race in
                    showRaceList = false
                    selectedRace = race
                    fitRace(race)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $sheetRace) { race in
            NavigationStack {
                RaceSummaryView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { sheetRace = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
        }
        .task {
            // 初回起動時のシーケンス:
            // 1. 日本全体を仮置き
            // 2. 250ms 後に fit-all（または 1件ズーム）と splash フェードを同時開始
            //    → MKMapView の region アニメ (~1s) と splash フェード (0.7s) が重なる
            guard !hasFitInitialRaces else { return }
            hasFitInitialRaces = true
            animate(toRegion: Self.japanRegion)
            try? await Task.sleep(for: .milliseconds(250))
            if !races.isEmpty {
                fitAllRaces()
            }
            splashCoordinator.beginHandoff()
        }
        .onChange(of: races.count) { _, newCount in
            // レース 0 件で起動して後から追加された場合、その時点で初回フィットを実行。
            if hasFitInitialRaces, newCount > 0, sheetRace == nil {
                fitAllRaces()
            }
        }
        .onChange(of: selectedRace) { _, race in
            guard let race else { return }
            zoomTask?.cancel()
            zoomTask = Task { await zoomThenPresent(race) }
        }
        .onChange(of: sheetRace) { _, race in
            // シート (下部ウィンドウ) の出現タイミングと完全に同期してアイコン化を切替える。
            // 時間で計らず sheetRace の変化そのものをトリガーにすることで、
            // ズーム所要時間や端末性能の差に関係なく「シートが出たらアイコン化」が成立する。
            // 閉じる側はカメラ位置は維持したままアイコン化のみ解除し、ピンを通常表示に戻す。
            iconifiedRace = race
        }
        .onChange(of: filters.category) { _, _ in
            // カテゴリ切替で残った範囲にリフィット。0 件のときは触らない。
            if !mappableRaces.isEmpty { fitAllRaces() }
        }
        .onChange(of: filters.year) { _, _ in
            if !mappableRaces.isEmpty { fitAllRaces() }
        }
    }

    /// ピン選択 → ピンを画面上半分の中央へ向けて滑らかにズーム → ズームが完全に
    /// 落ち着いてからシート (下部ウィンドウ) 表示。アイコン化は `sheetRace` の onChange で
    /// シート出現と同期して行うため、ここでは時間で測らない。
    private func zoomThenPresent(_ race: Race) async {
        // 別ピンが既に拡大中なら一旦解除。新しいズーム中に古いピンが大きいままだと
        // 視点が混乱するので、ズーム開始と同時にリセットしておく。
        iconifiedRace = nil
        fitRace(race)
        // ズームが完全に静止してからシートを上げる。fitRace の sin カーブアニメは
        // 距離依存で 0.6〜2.0 秒。最長ケースでも止まり切るよう、それより少し長めに待つ。
        try? await Task.sleep(for: .milliseconds(2100))
        guard !Task.isCancelled else { return }
        sheetRace = race
        // ズーム後の sheet 表示で `selectedRace` をリセット。次回タップで onChange が再発火する。
        selectedRace = nil
    }

    // MARK: - Layers

    @ViewBuilder
    private var mapLayer: some View {
#if os(iOS)
        RaceListMapView(
            races: mappableRaces,
            selectedRace: $selectedRace,
            iconifiedRace: iconifiedRace,
            requestedRegion: $requestedRegion,
            requestedRegionUpperHalf: requestedRegionUpperHalf,
            requestedZoom: $requestedZoom,
            currentCenter: $currentMapCenter,
            mapSettings: mapSettings,
            pinSettings: pinSettings
        )
        // ColorSchemeOverride 内側でも `.ignoresSafeArea` を入れる。UIHostingController で
        // ホスト境界が独自の safeArea を持つため、外側だけだと MKMapView が status bar
        // 領域までフレームを伸ばさない。両側で指定して確実に画面上端まで描画させる。
        .ignoresSafeArea(.all, edges: .top)
#else
        Color.bgSecondary
            .overlay(Text("Map (iOS only)").foregroundStyle(.secondary))
#endif
    }

    @ViewBuilder
    private var overlayLayer: some View {
        // 上下とも safe area 尊重なので SwiftUI が自動で safeAreaInsets を補正する。
        // GeometryReader での手動補正は不要。
        VStack {
            HStack(spacing: 8) {
                HamburgerButton(action: { showRaceList = true })
                Spacer()
                MapShareButton(
                    action: { showMapShareSheet = true },
                    disabled: mappableRaces.isEmpty
                )
                LayersButton(mapSettings: $mapSettings, pinSettings: $pinSettings)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            if races.isEmpty {
                Text("Tap + to import a workout file, or load sample races from Settings → Developer.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            } else if mappableRaces.isEmpty, filters.isActive {
                Text("No races match the current filter.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            HStack(alignment: .bottom) {
                Spacer()
                VStack(spacing: 10) {
                    MapActionsCluster(
                        onZoomIn: { requestedZoom = .in },
                        onZoomOut: { requestedZoom = .out },
                        onFitAll: fitAllRaces,
                        onResetJapan: {
                            animate(toRegion: Self.japanRegion)
                        },
                        canFitAll: !mappableRaces.isEmpty
                    )
                    MapAddFAB(races: races)
                }
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    /// レース 1 件にフィットする。ピン位置を画面上半分の中央に置く近接ズーム。
    /// 直後にシートが下半分を覆う前提で、シートに隠れない位置にピンを寄せておく。
    /// (ルートは RESULTS 詳細のミニマップ側で見るので、メイン地図ではピン拡大に専念)。
    private func fitRace(_ race: Race) {
        animate(
            toRegion: MKCoordinateRegion(
                center: race.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ),
            upperHalf: true
        )
    }

    private func fitAllRaces() {
        // 位置未設定 (0,0) のレースを fit 対象に含めると、center が大幅にズレるので除外。
        let mapped = mappableRaces
        guard !mapped.isEmpty else { return }
        let coords = mapped.map(\.coordinate)
        animate(toRegion: regionFitting(coords, minSpan: 0.05))
    }

    private func regionFitting(_ coords: [CLLocationCoordinate2D], minSpan: Double = 0.005) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.max()! - lats.min()!, minSpan) * 1.5,
            longitudeDelta: max(lngs.max()! - lngs.min()!, minSpan) * 1.5
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func animate(toRegion region: MKCoordinateRegion, upperHalf: Bool = false) {
        // RaceListMapView (UIViewRepresentable) は requestedRegion バインディングを
        // 監視して setRegion(animated: true) を呼ぶ。SwiftUI の withAnimation は不要。
        // upperHalf フラグは region と同タイミングで反映され、updateUIView から
        // edgePadding に流れる。
        requestedRegionUpperHalf = upperHalf
        requestedRegion = region
    }
}

// MARK: - Floating overlay components

/// 左上ハンバーガー: タップで race list ドロワーを開く。
/// (Web 版 marathon-record-app の Sidebar への入口に相当)
struct HamburgerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Races")
    }
}

/// 右上の共有ボタン (Layers の隣)。タップで `MapShareSheet` を開く。
/// レースが 0 件のときはタップを無効化して見た目も dim にする。
struct MapShareButton: View {
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
        .accessibilityLabel("Share Map")
    }
}

/// 右下の小さめアクションクラスタ: ズーム / フィット / 日本表示。
/// レース・結果の追加は別途 `MapAddFAB` (大型ネオン FAB) が担当する。
/// デモサンプル投入は Settings → Developer に移設した。
struct MapActionsCluster: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFitAll: () -> Void
    let onResetJapan: () -> Void
    let canFitAll: Bool

    var body: some View {
        VStack(spacing: 8) {
            // ズーム IN/OUT は同じカード内に二段で詰めて、フィット系と視覚的に分ける。
            VStack(spacing: 0) {
                floatIconButton(systemName: "plus", label: "Zoom in", action: onZoomIn)
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 0.5)
                    .frame(maxWidth: 28)
                floatIconButton(systemName: "minus", label: "Zoom out", action: onZoomOut)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)

            floatButton(systemName: "scope", label: "Fit All Races", action: onFitAll)
                .opacity(canFitAll ? 1 : 0.4)
                .disabled(!canFitAll)
            floatButton(systemName: "globe.asia.australia", label: "View Japan", action: onResetJapan)
        }
    }

    /// ズームボタン専用の中身 (背景はクラスタ側でまとめてかける)。
    @ViewBuilder
    private func floatIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func floatButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
