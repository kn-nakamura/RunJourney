#if os(iOS)
import SwiftUI
import SwiftData
import MapKit

/// レース一覧用の MKMapView ラッパー。
///
/// SwiftUI 標準の `Map` ビュー（iOS 17+）は **iOS 26 でタブバーアピアランスを内部的に
/// 壊し、MAP タブだけタブラベル書体がシステムフォントに戻る不具合**を起こすため使えない。
/// MKMapView を `UIViewRepresentable` で直接ラップするとこの副作用が消える。
///
/// ピンの見た目は SwiftUI `RaceAnnotationView` を `ImageRenderer` で UIImage 化して
/// 各 `MKAnnotationView.image` に流し込んでいるので、`PinSettings` の Shape / SymbolMode /
/// ColorSource / Size / Border はすべて反映される。`showName` だけは座標アンカー計算が
/// 複雑になるため snapshot 時に無効化している（ピンタップ時はシートが開くので冗長）。
struct RaceListMapView: UIViewRepresentable {
    let races: [Race]
    /// ピンタップで親に伝える「カメラを動かしたい対象」。シート表示用 `sheetRace` とは分離。
    @Binding var selectedRace: Race?
    /// シート表示中レース。アイコン化／ルート描画はこちらをソースにすることで、
    /// ズーム完了 (≒ シート出現) 後にピンが拡大するよう自然に遅延させる。
    @Binding var sheetRace: Race?
    /// 親から要求された一回限りのカメラ region 変更。`nil` = 何もしない。
    /// 反映後はバインディング側で `nil` に戻す。
    @Binding var requestedRegion: MKCoordinateRegion?
    let selectedRouteCoords: [CLLocationCoordinate2D]
    let mapSettings: MapStyleSettings
    let pinSettings: PinSettings
    /// シートが地図下部を覆う高さ (pt)。`setVisibleMapRect` の bottom edge padding に流す。
    /// 0 のときはシートなしの通常フィット動作。
    var bottomInset: CGFloat = 0

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = false
        mapView.preferredConfiguration = mapSettings.mapConfiguration
        // 起動時の region は親が onAppear で fitAllRaces を呼ぶ想定。
        // ここではデフォルトとして日本全体を仮置きする。
        mapView.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.0),
            span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 13.0)
        ), animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // マップスタイル
        mapView.preferredConfiguration = mapSettings.mapConfiguration

        // 状態変更検知用に最新値を保持。`mapView(_:viewFor:)` から参照される。
        context.coordinator.parent = self

        // アノテーション diff: 既存と現 races の差分だけ反映する。
        // 全消し再追加だと選択中ピンが消えて再生されてフリッカーするので diff 方式。
        let existingByID = Dictionary(
            uniqueKeysWithValues: mapView.annotations
                .compactMap { $0 as? RaceAnnotation }
                .map { ($0.race.persistentModelID, $0) }
        )
        let currentIDs = Set(races.map(\.persistentModelID))
        let stale = existingByID.filter { !currentIDs.contains($0.key) }.map(\.value)
        mapView.removeAnnotations(stale)

        let existingIDs = Set(existingByID.keys)
        let newAnnotations = races
            .filter { !existingIDs.contains($0.persistentModelID) }
            .map { RaceAnnotation(race: $0) }
        mapView.addAnnotations(newAnnotations)

        // 既存ピンの image を最新の状態 (selectedRace / pinSettings) で更新する。
        for annotation in mapView.annotations {
            guard let raceAnno = annotation as? RaceAnnotation,
                  let view = mapView.view(for: annotation) else { continue }
            context.coordinator.applyImage(to: view, for: raceAnno)
        }

        // ポリライン同期 (シート表示中のレース＝ `sheetRace` のルートを描画する)
        let oldOverlays = mapView.overlays.compactMap { $0 as? RoutePolyline }
        mapView.removeOverlays(oldOverlays)
        if !selectedRouteCoords.isEmpty, let race = sheetRace {
            let line = RoutePolyline(coordinates: selectedRouteCoords, count: selectedRouteCoords.count)
            line.strokeColor = UIColor(race.category.pinColor)
            mapView.addOverlay(line)
        }

        // 親が要求した region 変更があれば反映。bottomInset>0 のときは
        // setVisibleMapRect に edgePadding を渡して、シート上の見える領域に
        // フィットさせる (ピンがシートに隠れないようカメラを上にずらす)。
        if let region = requestedRegion {
            let mapRect = Self.makeMapRect(region: region)
            let padding = UIEdgeInsets(top: 32, left: 32, bottom: max(bottomInset, 0), right: 32)
            mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: true)
            DispatchQueue.main.async {
                self.requestedRegion = nil
            }
        }
    }

    /// `MKCoordinateRegion` (center+span) を `MKMapRect` に変換する。
    /// `setVisibleMapRect:edgePadding:animated:` は `MKMapRect` を要求するため。
    private static func makeMapRect(region: MKCoordinateRegion) -> MKMapRect {
        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        )
        let topLeftPoint = MKMapPoint(topLeft)
        let bottomRightPoint = MKMapPoint(bottomRight)
        return MKMapRect(
            x: min(topLeftPoint.x, bottomRightPoint.x),
            y: min(topLeftPoint.y, bottomRightPoint.y),
            width: abs(bottomRightPoint.x - topLeftPoint.x),
            height: abs(bottomRightPoint.y - topLeftPoint.y)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RaceListMapView

        init(parent: RaceListMapView) {
            self.parent = parent
        }

        // MARK: Annotation views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let raceAnno = annotation as? RaceAnnotation else { return nil }
            let identifier = "RacePin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: raceAnno, reuseIdentifier: identifier)
            view.annotation = raceAnno
            view.canShowCallout = false
            view.displayPriority = .required
            applyImage(to: view, for: raceAnno)
            return view
        }

        /// 現在の `sheetRace` / `pinSettings` で SwiftUI `RaceAnnotationView` を
        /// 描画して `MKAnnotationView.image` に流し込む。アンカー位置も pin 形状で調整。
        ///
        /// `isSelected` のソースは `selectedRace` ではなく `sheetRace` を使うことで、
        /// ズーム完了 (= シート表示開始) 後にピンが拡大／アイコン化するよう自然に遅延する。
        /// (タップ直後の `selectedRace = race` からズーム中はピンは小さいまま。)
        func applyImage(to view: MKAnnotationView, for raceAnno: RaceAnnotation) {
            let isSelected = parent.sheetRace?.persistentModelID == raceAnno.race.persistentModelID
            // showName は snapshot 時のアンカー計算を複雑にするので強制 OFF。
            var settings = parent.pinSettings
            settings.showName = false
            // ImageRenderer は SwiftUI の `.shadow()` を view の bounds 外側へ
            // 描画した分まで含めずに切ってしまうことがある（ピンの上端が削れて見える原因）。
            // 透明 padding を被せることでシャドウ全体を画像内に収める。
            let padding: CGFloat = 8
            let swiftUIView = RaceAnnotationView(
                race: raceAnno.race,
                isSelected: isSelected,
                settings: settings
            )
            .padding(padding)
            let renderer = ImageRenderer(content: swiftUIView)
            renderer.scale = view.traitCollection.displayScale
            guard let image = renderer.uiImage else { return }
            view.image = image
            // pin (teardrop) は尖り先 (= 画像下端から padding 分上) を座標に合わせる。
            // それ以外の形 (dot/ring/square) は画像中央を座標に合わせる。
            if parent.pinSettings.shape == .pin {
                view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2 + padding)
            } else {
                view.centerOffset = .zero
            }
        }

        // MARK: Overlay renderers

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? RoutePolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = line.strokeColor
                r.lineWidth = 5
                r.lineCap = .round
                r.lineJoin = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: Selection

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let raceAnno = view.annotation as? RaceAnnotation else { return }
            // 親 SwiftUI 状態を更新。次のランループで sheet が開く。
            DispatchQueue.main.async {
                self.parent.selectedRace = raceAnno.race
            }
            // MKMapView 側の selection は即座に解除して、再タップ時にもう一度
            // didSelect が走るようにしておく (sheet 閉じた後の挙動を素直にする)。
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}

// MARK: - Annotation / Overlay model

final class RaceAnnotation: NSObject, MKAnnotation {
    let race: Race
    init(race: Race) { self.race = race }
    var coordinate: CLLocationCoordinate2D { race.coordinate }
    var title: String? { race.name.isEmpty ? "Race" : race.name }
}

private final class RoutePolyline: MKPolyline {
    var strokeColor: UIColor = .systemYellow
}
#endif
