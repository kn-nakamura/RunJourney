import SwiftUI
import SwiftData
import MapKit

/// メインの地図画面。全レースを色分けピンで表示し、タップで詳細を開く。
/// マップ右下の Layers ボタンから `MapStylePanel` を開いてスタイル/ピンをカスタマイズできる。
struct RaceMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Race.createdAt, order: .reverse) private var races: [Race]

    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    @State private var cameraPosition: MapCameraPosition = .region(Self.japanRegion)
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
        // MapKit の内部 UIView は SwiftUI の preferredColorScheme より UIKit 由来の
        // overrideUserInterfaceStyle を見るので、ColorSchemeOverride で包んで強制する。
        ColorSchemeOverride(scheme: mapSettings.preferredColorScheme) {
            Map(position: $cameraPosition, selection: $selectedRace) {
                ForEach(races) { race in
                    Annotation(
                        race.name.isEmpty ? "レース" : race.name,
                        coordinate: race.coordinate,
                        anchor: pinSettings.shape == .pin ? .bottom : .center
                    ) {
                        RaceAnnotationView(
                            race: race,
                            isSelected: selectedRace == race,
                            settings: pinSettings
                        )
                    }
                    .tag(race)
                }

                if let race = selectedRace, !selectedRouteCoordinates.isEmpty {
                    MapPolyline(coordinates: selectedRouteCoordinates)
                        .stroke(race.category.pinColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(mapSettings.mapStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        }
        // フルスクリーン: ナビゲーションバーと TabBar の下まで地図を広げる。
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .overlay(alignment: .topLeading) {
            // 左上: ハンバーガー → レース一覧ドロワー
            HamburgerButton(action: { showRaceList = true })
                .padding(.top, 12)
                .padding(.leading, 12)
        }
        .overlay(alignment: .topTrailing) {
            // 右上のフロート: Layers ボタン
            LayersButton(mapSettings: $mapSettings, pinSettings: $pinSettings)
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .overlay(alignment: .bottomTrailing) {
            // 右下フロートのアクションクラスタ: インポート / ダミー追加 / フィット / 日本表示。
            // (元はナビゲーションバーのツールバーにあったが、フルスクリーン化のため画面内に移動)
            MapActionsCluster(
                onImport: nil, // FileImportButton を内部で使うため不要
                onAddDummy: addDummyRaceNearTokyo,
                onFitAll: fitAllRaces,
                onFitRoute: fitSelectedRoute,
                onResetJapan: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        cameraPosition = .region(Self.japanRegion)
                    }
                },
                canFitAll: !races.isEmpty,
                canFitRoute: !selectedRouteCoordinates.isEmpty
            )
            .padding(.trailing, 12)
            .padding(.bottom, 96)   // TabBar 高さ + safe area 分を確保
        }
        .overlay(alignment: .top) {
            if races.isEmpty {
                Text("右下の ↓ から TCX / GPX を取り込み、または + でダミーレースを追加")
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 64)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }
        }
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
                            Button("閉じる") { selectedRace = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            // 初回のみ、レースがあればそこにフィット。0 件なら Japan region のまま見せる。
            if !hasFitInitialRaces, !races.isEmpty {
                hasFitInitialRaces = true
                fitAllRaces()
            }
        }
        .onChange(of: races.count) { _, newCount in
            // インポート直後など、レースが追加されたら一度だけフィット
            if !hasFitInitialRaces, newCount > 0 {
                hasFitInitialRaces = true
                fitAllRaces()
            }
        }
    }

    /// MVP用ダミー追加。Phase 3 で TCX/GPX/FIT 取り込みダイアログに置き換える。
    private func addDummyRaceNearTokyo() {
        let samples: [(String, RaceCategory, Double, Double, String)] = [
            ("東京マラソン", .fullMarathon, 35.6909, 139.6917, "Tokyo"),
            ("湘南国際マラソン", .fullMarathon, 35.3220, 139.4811, "Fujisawa"),
            ("大阪マラソン", .fullMarathon, 34.6937, 135.5023, "Osaka"),
            ("北海道マラソン", .fullMarathon, 43.0667, 141.3500, "Sapporo"),
            ("ハセツネカップ", .trail, 35.7375, 139.1453, "Tokyo"),
            ("青梅マラソン", .halfMarathon, 35.7878, 139.2756, "Ome"),
            ("板橋Cityマラソン", .fullMarathon, 35.7611, 139.6833, "Itabashi"),
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
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.max()! - lats.min()!, 0.005) * 1.4,
            longitudeDelta: max(lngs.max()! - lngs.min()!, 0.005) * 1.4
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    /// レース 1 件にフィットする。トラックポイントがあればルート全体にフィットし、
    /// 無ければピン位置に約 5km 範囲でズームする。
    private func fitRace(_ race: Race) {
        let coords = (race.results?.first(where: { !$0.trackPoints.isEmpty })?.trackPoints ?? [])
            .map(\.coordinate)
        if coords.count >= 2 {
            let lats = coords.map(\.latitude)
            let lngs = coords.map(\.longitude)
            let center = CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lngs.min()! + lngs.max()!) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max(lats.max()! - lats.min()!, 0.005) * 1.4,
                longitudeDelta: max(lngs.max()! - lngs.min()!, 0.005) * 1.4
            )
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: race.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }

    private func fitAllRaces() {
        guard !races.isEmpty else { return }
        let lats = races.map(\.lat)
        let lngs = races.map(\.lng)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.05) * 1.5,
            longitudeDelta: max(maxLng - minLng, 0.05) * 1.5
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// （RaceDetailView, RaceResultRow は Features/Detail/ 配下に移動）

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
        .accessibilityLabel("レース一覧")
    }
}

/// 元はナビゲーションバーのツールバー項目だった「インポート / ダミー追加 / フィット / 日本表示」を
/// 縦に積んだフロート群。マップフルスクリーン化に伴い右下に移動した。
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
            // インポート: FileImportButton はピッカー UI を内包する独自 Button なので、
            // labelStyle.iconOnly + tint で見た目を浮きボタンに揃える
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

            floatButton(systemName: "plus", label: "ダミー追加", action: onAddDummy)
            floatButton(systemName: "scope", label: "全レースを表示", action: onFitAll)
                .opacity(canFitAll ? 1 : 0.4)
                .disabled(!canFitAll)
            floatButton(systemName: "arrow.up.left.and.arrow.down.right", label: "ルートにフィット", action: onFitRoute)
                .opacity(canFitRoute ? 1 : 0.4)
                .disabled(!canFitRoute)
            floatButton(systemName: "globe.asia.australia", label: "日本全体", action: onResetJapan)
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
