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
    @Environment(\.modelContext) private var modelContext
    @Environment(SplashCoordinator.self) private var splashCoordinator
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

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
    /// 3 つに分離することで、ズーム → シート → アイコン化を時間差で発生させる。
    @State private var selectedRace: Race?
    @State private var sheetRace: Race?
    /// ピンを「拡大＋アイコン表示」状態にするレース。シート出現から少し遅らせて
    /// セットすることで、ズーム & シート開きが完全に終わった後に
    /// ピンが滑らかにアイコンへ切り替わるよう演出する。
    @State private var iconifiedRace: Race?
    @State private var zoomTask: Task<Void, Never>?
    @State private var hasFitInitialRaces = false
    @State private var showRaceList = false

    /// レース 0 件で起動したときに見せるデフォルト region。日本全体がふんわり収まるサイズ。
    private static let japanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.0),
        span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 13.0)
    )

    var body: some View {
        ZStack {
            mapLayer
            overlayLayer
        }
        // 上下とも safe area を尊重: status bar / Dynamic Island や TabBar の裏に
        // 地図がはみ出さないようにする。
        // (top の ignoresSafeArea は status bar 領域に地図が透けて読みづらくなるため撤去。
        //  bottom の ignoresSafeArea は iOS 26 タブバーアピアランスを壊すため不可。)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .sheet(isPresented: $showRaceList) {
            RaceListDrawer(
                races: races,
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
                RaceDetailView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { sheetRace = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
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
            // シートが閉じたら全体ビューに戻す。Web 版と同じ挙動。
            if race == nil, !races.isEmpty {
                iconifiedRace = nil
                fitAllRaces()
            }
        }
    }

    /// ピン選択 → ピンを画面上半分の中央へ向けて滑らかにズーム → ズームが完全に
    /// 落ち着いてからシート表示 → さらに少し置いてピンを拡大＋アイコン化。
    /// MKMapView の region アニメは大ズーム時に最大 ~1s 近くかかるため、
    /// シート出現前に十分なバッファを取って「ピンが動き切ってからシートが出る」
    /// 体感にする (= 減速感)。
    private func zoomThenPresent(_ race: Race) async {
        // 別ピンが既に拡大中なら一旦解除。新しいズーム中に古いピンが大きいままだと
        // 視点が混乱するので、ズーム開始と同時にリセットしておく。
        iconifiedRace = nil
        fitRace(race)
        // ズームが完全に静止してからシートを上げる。バッファを広めに取り、
        // 「ピンが止まる→ひと呼吸置いてシート」のリズムにする。
        try? await Task.sleep(for: .milliseconds(1200))
        guard !Task.isCancelled else { return }
        sheetRace = race
        // ズーム後の sheet 表示で `selectedRace` をリセット。次回タップで onChange が再発火する。
        selectedRace = nil
        // シートが完全に展開してから少し置いてピンを拡大＋アイコン化する。
        // 直前にシートのプレゼンテーションアニメ (~0.5s) が走るので、
        // それと重ならないように 1.3 秒待つ。
        try? await Task.sleep(for: .milliseconds(1300))
        guard !Task.isCancelled else { return }
        iconifiedRace = race
    }

    // MARK: - Layers

    @ViewBuilder
    private var mapLayer: some View {
#if os(iOS)
        RaceListMapView(
            races: races,
            selectedRace: $selectedRace,
            iconifiedRace: iconifiedRace,
            requestedRegion: $requestedRegion,
            requestedRegionUpperHalf: requestedRegionUpperHalf,
            mapSettings: mapSettings,
            pinSettings: pinSettings
        )
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
            HStack {
                HamburgerButton(action: { showRaceList = true })
                Spacer()
                LayersButton(mapSettings: $mapSettings, pinSettings: $pinSettings)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            if races.isEmpty {
                Text("Import TCX / GPX from the toolbar, or tap + to load sample races")
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            HStack {
                Spacer()
                MapActionsCluster(
                    onImport: nil,
                    onAddDummy: addDummyRaceNearTokyo,
                    onFitAll: fitAllRaces,
                    onResetJapan: {
                        animate(toRegion: Self.japanRegion)
                    },
                    canFitAll: !races.isEmpty
                )
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    /// MVP用ダミー追加。Phase 3 で TCX/GPX/FIT 取り込みダイアログに置き換える。
    /// 既登録の名前は重複追加しないので、何度押しても 8 件に揃う。
    private func addDummyRaceNearTokyo() {
        let samples: [(String, RaceCategory, Double, Double, String)] = [
            ("Tokyo Marathon", .fullMarathon, 35.6909, 139.6917, "Tokyo"),
            ("Shonan International Marathon", .fullMarathon, 35.3220, 139.4811, "Fujisawa"),
            ("Osaka Marathon", .fullMarathon, 34.6937, 135.5023, "Osaka"),
            ("Hokkaido Marathon", .fullMarathon, 43.0667, 141.3500, "Sapporo"),
            ("Hasetsune Cup", .trail, 35.7375, 139.1453, "Tokyo"),
            ("Ome Marathon", .halfMarathon, 35.7878, 139.2756, "Ome"),
            ("Itabashi City Marathon", .fullMarathon, 35.7611, 139.6833, "Itabashi"),
            ("UTMF", .ultraCustom, 35.4361, 138.7186, "Fujikawaguchiko"),
        ]
        let existingNames = Set(races.map(\.name))
        for sample in samples where !existingNames.contains(sample.0) {
            let race = Race(
                name: sample.0,
                category: sample.1,
                address: sample.4,
                city: sample.4,
                country: "Japan",
                lat: sample.2,
                lng: sample.3
            )
            modelContext.insert(race)
        }
    }

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
        guard !races.isEmpty else { return }
        let coords = races.map(\.coordinate)
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

/// 右下のアクションクラスタ: インポート / ダミー追加 / フィット / 日本表示。
struct MapActionsCluster: View {
    let onImport: (() -> Void)?           // 外部から差し替えたい場合用 (現状は内部 FileImportButton)
    let onAddDummy: () -> Void
    let onFitAll: () -> Void
    let onResetJapan: () -> Void
    let canFitAll: Bool

    var body: some View {
        VStack(spacing: 8) {
            FileImportButton()
                .labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .semibold))
                .tint(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)

            floatButton(systemName: "plus", label: "Add Sample", action: onAddDummy)
            floatButton(systemName: "scope", label: "Fit All Races", action: onFitAll)
                .opacity(canFitAll ? 1 : 0.4)
                .disabled(!canFitAll)
            floatButton(systemName: "globe.asia.australia", label: "View Japan", action: onResetJapan)
        }
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
