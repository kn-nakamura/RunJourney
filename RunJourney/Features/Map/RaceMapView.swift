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
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    /// MKMapView へ渡す「一回限りの region 変更要求」。fit 操作時にセットし、
    /// 反映後は MKMapView 側で nil に戻される。
    @State private var requestedRegion: MKCoordinateRegion?
    @State private var selectedRace: Race?
    @State private var hasFitInitialRaces = false
    @State private var showRaceList = false

    /// レース 0 件で起動したときに見せるデフォルト region。日本全体がふんわり収まるサイズ。
    private static let japanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.0),
        span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 13.0)
    )

    /// 選択中レースの最初のトラックポイント付き結果のルートを描画する。
    private var selectedRouteCoordinates: [CLLocationCoordinate2D] {
        guard let race = selectedRace,
              let result = race.results?.first(where: { !$0.trackPoints.isEmpty })
        else { return [] }
        return result.trackPoints.map(\.coordinate)
    }

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
        .sheet(item: $selectedRace) { race in
            NavigationStack {
                RaceDetailView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { selectedRace = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if !hasFitInitialRaces, !races.isEmpty {
                hasFitInitialRaces = true
                fitAllRaces()
            }
        }
        .onChange(of: races.count) { _, newCount in
            if !hasFitInitialRaces, newCount > 0 {
                hasFitInitialRaces = true
                fitAllRaces()
            }
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private var mapLayer: some View {
#if os(iOS)
        RaceListMapView(
            races: races,
            selectedRace: $selectedRace,
            requestedRegion: $requestedRegion,
            selectedRouteCoords: selectedRouteCoordinates,
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
                Text("Import TCX / GPX from the toolbar, or tap + to add a sample race")
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
                    onFitRoute: fitSelectedRoute,
                    onResetJapan: {
                        requestedRegion = Self.japanRegion
                    },
                    canFitAll: !races.isEmpty,
                    canFitRoute: !selectedRouteCoordinates.isEmpty
                )
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Actions

    /// MVP用ダミー追加。Phase 3 で TCX/GPX/FIT 取り込みダイアログに置き換える。
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
        let pick = samples[races.count % samples.count]
        let race = Race(
            name: pick.0,
            category: pick.1,
            address: pick.4,
            city: pick.4,
            country: "Japan",
            lat: pick.2,
            lng: pick.3
        )
        modelContext.insert(race)
    }

    private func fitSelectedRoute() {
        let coords = selectedRouteCoordinates
        guard coords.count >= 2 else { return }
        animate(toRegion: regionFitting(coords))
    }

    /// レース 1 件にフィットする。トラックポイントがあればルート全体にフィットし、
    /// 無ければピン位置に約 5km 範囲でズームする。
    private func fitRace(_ race: Race) {
        let coords = (race.results?.first(where: { !$0.trackPoints.isEmpty })?.trackPoints ?? [])
            .map(\.coordinate)
        if coords.count >= 2 {
            animate(toRegion: regionFitting(coords))
        } else {
            animate(toRegion: MKCoordinateRegion(
                center: race.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
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

    private func animate(toRegion region: MKCoordinateRegion) {
        // RaceListMapView (UIViewRepresentable) は requestedRegion バインディングを
        // 監視して setRegion(animated: true) を呼ぶ。SwiftUI の withAnimation は不要。
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
    let onFitRoute: () -> Void
    let onResetJapan: () -> Void
    let canFitAll: Bool
    let canFitRoute: Bool

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
            floatButton(systemName: "arrow.up.left.and.arrow.down.right", label: "Fit Route", action: onFitRoute)
                .opacity(canFitRoute ? 1 : 0.4)
                .disabled(!canFitRoute)
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
