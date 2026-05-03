#if canImport(UIKit)
import SwiftUI
import MapKit
import UIKit

/// 高頻度更新でも MKPolyline が消失しない MKMapView 直叩きラッパー。
///
/// 設計方針:
/// - 全体ルート (ダークグレー) は init 時に 1 度だけ MKPolyline を作って固定する
/// - 走破ラインは `traveledIndex` が動いた時だけ MKPolyline を作り直す（新追加→旧削除の順）
/// - 末端ヒゲ (直近トラックポイント → 補間中の現在位置) は毎フレーム作り直すが 2 点のみ
/// - ランナーマーカーは小さいドットのみ（figure.run アイコンなし）
/// - ユーザ操作の検知はジェスチャレコグナイザーで行う。MKMapViewDelegate では
///   プログラム的カメラ更新も regionWillChangeAnimated に来るため誤検知が起きる
struct FlythroughMapView: UIViewRepresentable {

    let allCoords: [CLLocationCoordinate2D]
    let trackPointCoords: [CLLocationCoordinate2D]
    let traveledIndex: Int
    let tailCoords: [CLLocationCoordinate2D]?
    /// ランナー現在位置（ドットマーカー用）。
    let runnerCoord: CLLocationCoordinate2D?
    let camera: MKMapCamera
    let configuration: MKMapConfiguration
    let strokeColor: UIColor
    let isPlaying: Bool
    /// true = Overview モード: setCamera を抑制し切替時に setVisibleMapRect を実行。
    let isOverview: Bool
    /// true = ユーザ操作中: setCamera を抑制。
    let isUserInteracting: Bool
    /// ユーザがマップをジェスチャ操作した時に呼ばれるコールバック。
    let onUserInteraction: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsScale = false
        map.showsUserLocation = false
        // ジェスチャはすべて有効 — ユーザはいつでもマップを操作できる
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true

        // ユーザ操作検知: ジェスチャレコグナイザーで検出する。
        // MKMapViewDelegate の regionWillChangeAnimated はプログラム的カメラ更新でも
        // 発火するため誤検知が起きる。ジェスチャレコグナイザーはタッチ起因のみ。
        for GestureType in [UIPanGestureRecognizer.self,
                            UIPinchGestureRecognizer.self,
                            UIRotationGestureRecognizer.self] as [UIGestureRecognizer.Type] {
            let g = GestureType.init(
                target: context.coordinator,
                action: #selector(Coordinator.handleUserGesture(_:))
            )
            g.cancelsTouchesInView = false
            g.delegate = context.coordinator
            map.addGestureRecognizer(g)
        }

        // 全体ルート (一度だけ追加、不変)
        if allCoords.count >= 2 {
            let poly = MKPolyline(coordinates: allCoords, count: allCoords.count)
            poly.title = OverlayKind.full.rawValue
            map.addOverlay(poly, level: .aboveRoads)
            context.coordinator.fullPolyline = poly
        }

        // スタート / フィニッシュ (一度だけ追加、不変)
        if let first = allCoords.first {
            map.addAnnotation(FlagAnnotation(coordinate: first, kind: .start))
        }
        if allCoords.count > 1, let last = allCoords.last {
            map.addAnnotation(FlagAnnotation(coordinate: last, kind: .finish))
        }

        // 現在位置ドット
        if let runner = runnerCoord {
            let a = PositionAnnotation(coordinate: runner)
            map.addAnnotation(a)
            context.coordinator.positionAnnotation = a
        }

        map.setCamera(camera, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coord = context.coordinator
        coord.onUserInteraction = onUserInteraction

        if !areConfigurationsEqual(map.preferredConfiguration, configuration) {
            map.preferredConfiguration = configuration
        }

        // 走破ライン: 新 polyline を追加してから旧を削除することでちらつきを防ぐ
        if traveledIndex != coord.lastTraveledIndex {
            let endIdx = min(traveledIndex, trackPointCoords.count - 1)
            var newPoly: MKPolyline?
            if endIdx >= 1 {
                let slice = Array(trackPointCoords[0...endIdx])
                newPoly = MKPolyline(coordinates: slice, count: slice.count)
                newPoly!.title = OverlayKind.traveled.rawValue
                map.addOverlay(newPoly!, level: .aboveRoads)  // 新を先に追加
            }
            if let old = coord.traveledPolyline {
                map.removeOverlay(old)  // 旧を後で削除
            }
            coord.traveledPolyline = newPoly
            coord.lastTraveledIndex = traveledIndex
        }

        // 末端ヒゲ: 毎フレーム作り直す。新追加→旧削除でちらつきを防ぐ
        var newTail: MKPolyline?
        if let tail = tailCoords, tail.count == 2 {
            newTail = MKPolyline(coordinates: tail, count: tail.count)
            newTail!.title = OverlayKind.tail.rawValue
            map.addOverlay(newTail!, level: .aboveRoads)  // 新を先に追加
        }
        if let old = coord.tailPolyline {
            map.removeOverlay(old)  // 旧を後で削除
        }
        coord.tailPolyline = newTail

        // 現在位置ドット: coordinate 差し替えのみ（再追加するとアニメが切れる）
        if let runner = runnerCoord {
            if let existing = coord.positionAnnotation {
                if !coordsEqual(existing.coordinate, runner) {
                    existing.coordinate = runner
                }
            } else {
                let a = PositionAnnotation(coordinate: runner)
                map.addAnnotation(a)
                coord.positionAnnotation = a
            }
        }

        // 色変更追従
        if coord.strokeColor != strokeColor {
            coord.strokeColor = strokeColor
            for overlay in map.overlays {
                if let renderer = map.renderer(for: overlay) as? MKPolylineRenderer,
                   let title = (overlay as? MKPolyline)?.title,
                   title == OverlayKind.traveled.rawValue || title == OverlayKind.tail.rawValue {
                    renderer.strokeColor = strokeColor
                    renderer.setNeedsDisplay()
                }
            }
        }

        // Overview モード切替時に bounding rect でルートを画面に収める
        if isOverview != coord.wasInOverview {
            coord.wasInOverview = isOverview
            if isOverview, let poly = coord.fullPolyline {
                let padding = UIEdgeInsets(top: 80, left: 40, bottom: 220, right: 40)
                map.setVisibleMapRect(poly.boundingMapRect, edgePadding: padding, animated: true)
            }
        }

        // フォローモード + ユーザ非操作時のみカメラを更新
        if !isOverview && !isUserInteracting {
            map.setCamera(camera, animated: false)
        }
    }

    private func areConfigurationsEqual(_ a: MKMapConfiguration, _ b: MKMapConfiguration) -> Bool {
        type(of: a) == type(of: b)
    }

    private func coordsEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var fullPolyline: MKPolyline?
        var traveledPolyline: MKPolyline?
        var tailPolyline: MKPolyline?
        var lastTraveledIndex: Int = -1
        var strokeColor: UIColor = .systemYellow
        var wasInOverview: Bool = false
        var positionAnnotation: PositionAnnotation?
        var onUserInteraction: (() -> Void)?

        // ユーザのジェスチャ（タッチ起因）のみを検知する。
        // プログラム的な setCamera では UIGestureRecognizer は発火しない。
        @objc func handleUserGesture(_ gesture: UIGestureRecognizer) {
            guard gesture.state == .began || gesture.state == .changed else { return }
            onUserInteraction?()
        }

        // マップ内蔵ジェスチャレコグナイザーと同時認識を許可
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: polyline)
            r.lineCap = .round
            r.lineJoin = .round
            switch polyline.title {
            case OverlayKind.full.rawValue:
                // marathon-record-app の #3A3A4A 相当のダークグレー
                r.strokeColor = UIColor(red: 58/255, green: 58/255, blue: 74/255, alpha: 0.85)
                r.lineWidth = 4
            case OverlayKind.traveled.rawValue, OverlayKind.tail.rawValue:
                r.strokeColor = strokeColor
                r.lineWidth = 5
            default:
                r.strokeColor = .white
                r.lineWidth = 4
            }
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pos = annotation as? PositionAnnotation {
                let id = "position"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? PositionAnnotationView)
                    ?? PositionAnnotationView(annotation: pos, reuseIdentifier: id)
                view.annotation = pos
                return view
            }
            if let flag = annotation as? FlagAnnotation {
                let id = "flag-\(flag.kind.rawValue)"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? FlagAnnotationView)
                    ?? FlagAnnotationView(annotation: flag, reuseIdentifier: id)
                view.annotation = flag
                view.configure(kind: flag.kind)
                return view
            }
            return nil
        }
    }

    private enum OverlayKind: String {
        case full, traveled, tail
    }
}

// MARK: - Annotations

/// 現在位置アノテーション。coordinate を var にして差し替え移動させる。
final class PositionAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

final class FlagAnnotation: NSObject, MKAnnotation {
    enum Kind: String { case start, finish }
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
}

// MARK: - Annotation Views

/// 現在位置を示す小さいドット（ランナーアイコンなし）。
final class PositionAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let size: CGFloat = 14
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = .zero
        backgroundColor = .clear

        let dot = CALayer()
        dot.frame = bounds
        dot.cornerRadius = size / 2
        dot.backgroundColor = UIColor.systemYellow.cgColor
        dot.shadowColor = UIColor.systemYellow.cgColor
        dot.shadowOpacity = 0.85
        dot.shadowRadius = 7
        dot.shadowOffset = .zero
        layer.addSublayer(dot)

        let border = CALayer()
        border.frame = bounds
        border.cornerRadius = size / 2
        border.borderColor = UIColor.white.cgColor
        border.borderWidth = 2
        border.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(border)
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }
}

final class FlagAnnotationView: MKAnnotationView {
    private let bg = CALayer()
    private let icon = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        centerOffset = .zero
        backgroundColor = .clear
        bg.frame = bounds
        bg.cornerRadius = bounds.width / 2
        layer.addSublayer(bg)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.frame = bounds.insetBy(dx: 5, dy: 5)
        addSubview(icon)
    }
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func configure(kind: FlagAnnotation.Kind) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        switch kind {
        case .start:
            icon.image = UIImage(systemName: "flag.checkered", withConfiguration: cfg)
            bg.backgroundColor = UIColor.systemGreen.cgColor
        case .finish:
            icon.image = UIImage(systemName: "flag.fill", withConfiguration: cfg)
            bg.backgroundColor = UIColor.systemRed.cgColor
        }
    }
}

// MARK: - MapStyleSettings → MKMapConfiguration

extension MapStyleSettings {
    var mapConfiguration: MKMapConfiguration {
        let elev: MKMapConfiguration.ElevationStyle = (elevation == .realistic ? .realistic : .flat)
        let pois: MKPointOfInterestFilter = poiFilter
        switch base {
        case .standard:
            let cfg = MKStandardMapConfiguration(elevationStyle: elev, emphasisStyle: .muted)
            cfg.pointOfInterestFilter = pois
            cfg.showsTraffic = showsTraffic
            return cfg
        case .hybrid:
            let cfg = MKHybridMapConfiguration(elevationStyle: elev)
            cfg.pointOfInterestFilter = pois
            cfg.showsTraffic = showsTraffic
            return cfg
        case .imagery:
            return MKImageryMapConfiguration(elevationStyle: elev)
        }
    }

    private var poiFilter: MKPointOfInterestFilter {
        switch poi {
        case .none:    return .excludingAll
        case .minimal: return MKPointOfInterestFilter(including: [.airport, .hospital, .park, .stadium])
        case .all:     return .includingAll
        }
    }
}
#endif
