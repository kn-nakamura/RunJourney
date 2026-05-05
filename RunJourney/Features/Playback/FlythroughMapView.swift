#if canImport(UIKit)
import SwiftUI
import MapKit
import UIKit

/// 高頻度更新でも軌跡が正確に表示される MKMapView ラッパー。
///
/// 設計方針:
/// - 全体ルート (ダークグレー MKPolyline) は init 時に 1 度だけ追加、不変
/// - 走破ライン: ProgressRouteOverlay (カスタム MKOverlay) で管理
///   → traveled[0...n] + runnerCoord(tip) を draw() 1 回で描くため add/remove なし
/// - ランナードット: PositionAnnotationView (MKAnnotationView / スクリーンスペース)
///   → CALayer.shadowRadius でグローが出る。スクリーン空間なので pitch に影響されず浮いて見える
///   → 線の先端は同じ runnerCoord なので updateUIView 1 回で両方が更新される
/// - ユーザ操作検知はジェスチャレコグナイザーで行う
struct FlythroughMapView: UIViewRepresentable {

    let allCoords: [CLLocationCoordinate2D]
    let trackPointCoords: [CLLocationCoordinate2D]
    let traveledIndex: Int
    /// ランナー補間現在位置。nil = 未再生。
    let runnerCoord: CLLocationCoordinate2D?
    let camera: MKMapCamera
    let configuration: MKMapConfiguration
    let strokeColor: UIColor
    let isPlaying: Bool
    /// true = Overview モード: setCamera を抑制し切替時に setVisibleMapRect を実行。
    let isOverview: Bool
    /// true = ユーザ操作中: setCamera を抑制。
    let isUserInteracting: Bool
    let onUserInteraction: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsScale = false
        map.showsUserLocation = false
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true

        // ユーザ操作検知: ジェスチャレコグナイザーで検出
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
            poly.title = OverlayKind.fullRoute.rawValue
            map.addOverlay(poly, level: .aboveRoads)
            context.coordinator.fullPolyline = poly
        }

        // 走破ライン + ランナードット: カスタムオーバーレイ (初期データは空)
        let progress = ProgressRouteOverlay(fullBoundingRect: context.coordinator.fullPolyline?.boundingMapRect ?? .world)
        progress.update(traveledCoords: [], runnerCoord: runnerCoord, strokeColor: strokeColor)
        map.addOverlay(progress, level: .aboveRoads)
        context.coordinator.progressOverlay = progress

        // スタート / フィニッシュフラグ (不変)
        if let first = allCoords.first {
            map.addAnnotation(FlagAnnotation(coordinate: first, kind: .start))
        }
        if allCoords.count > 1, let last = allCoords.last {
            map.addAnnotation(FlagAnnotation(coordinate: last, kind: .finish))
        }

        // ランナードット annotation (runnerCoord が確定してから addAnnotation)
        // → updateUIView で管理

        map.setCamera(camera, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coord = context.coordinator
        coord.onUserInteraction = onUserInteraction

        if !areConfigurationsEqual(map.preferredConfiguration, configuration) {
            map.preferredConfiguration = configuration
        }

        // 走破ライン更新: 60fps に制限してタイルレンダラーの thrash を防ぐ
        let now = CACurrentMediaTime()
        if now - coord.lastLineUpdateTime >= 1.0 / 60.0, let overlay = coord.progressOverlay {
            coord.lastLineUpdateTime = now
            let endIdx = min(traveledIndex, trackPointCoords.count - 1)
            let traveled: [CLLocationCoordinate2D] = endIdx >= 0
                ? Array(trackPointCoords[0...endIdx])
                : []
            overlay.update(traveledCoords: traveled, runnerCoord: runnerCoord, strokeColor: strokeColor)
            if let renderer = map.renderer(for: overlay) as? ProgressRouteRenderer {
                renderer.setNeedsDisplay()
            }
        }

        // ランナードット annotation (MKAnnotationView = スクリーンスペース = 浮いて見える)
        if let runner = runnerCoord {
            if let ann = coord.positionAnnotation {
                ann.coordinate = runner
            } else {
                let ann = PositionAnnotation(coordinate: runner, dotColor: strokeColor)
                coord.positionAnnotation = ann
                map.addAnnotation(ann)
            }
        } else if let ann = coord.positionAnnotation {
            map.removeAnnotation(ann)
            coord.positionAnnotation = nil
        }

        // Overview モード切替
        if isOverview != coord.wasInOverview {
            coord.wasInOverview = isOverview
            if isOverview, let poly = coord.fullPolyline {
                let padding = UIEdgeInsets(top: 80, left: 40, bottom: 220, right: 40)
                map.setVisibleMapRect(poly.boundingMapRect, edgePadding: padding, animated: true)
            }
        }

        if !isOverview && !isUserInteracting {
            map.setCamera(camera, animated: false)
        }
    }

    private func areConfigurationsEqual(_ a: MKMapConfiguration, _ b: MKMapConfiguration) -> Bool {
        type(of: a) == type(of: b)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var fullPolyline: MKPolyline?
        var progressOverlay: ProgressRouteOverlay?
        var positionAnnotation: PositionAnnotation?
        var wasInOverview: Bool = false
        var onUserInteraction: (() -> Void)?
        /// ラインレンダラーは60fpsに制限（120Hzで setNeedsDisplay するとタイル再描画が
        /// 常にキャンセルされ軌跡が消える）。ドット annotation は制限なし。
        var lastLineUpdateTime: CFTimeInterval = 0

        @objc func handleUserGesture(_ gesture: UIGestureRecognizer) {
            guard gesture.state == .began || gesture.state == .changed else { return }
            onUserInteraction?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let progress = overlay as? ProgressRouteOverlay {
                return ProgressRouteRenderer(overlay: progress)
            }
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: polyline)
            r.lineCap = .round
            r.lineJoin = .round
            if polyline.title == OverlayKind.fullRoute.rawValue {
                // 走破前のフルルートは「うっすら筋が見える」程度。Light テーマではダーク
                // ビジュアルでは目立たない暖灰色 borderColor が、ダーク/ライトどちらでも
                // 同じ「控えめな下書き」表現になる。
                r.strokeColor = UIColor(Color.borderColor).withAlphaComponent(0.85)
                r.lineWidth = 4
            } else {
                // 走破済みの輝線。Dark では白、Light ではほぼ黒に切替えてコントラストを確保。
                r.strokeColor = UIColor(Color.textPrimary)
                r.lineWidth = 4
            }
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pos = annotation as? PositionAnnotation {
                let id = "runner"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? PositionAnnotationView)
                    ?? PositionAnnotationView(annotation: pos, reuseIdentifier: id)
                view.annotation = pos
                view.configure(color: pos.dotColor)
                return view
            }
            guard let flag = annotation as? FlagAnnotation else { return nil }
            let id = "flag-\(flag.kind.rawValue)"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? FlagAnnotationView)
                ?? FlagAnnotationView(annotation: flag, reuseIdentifier: id)
            view.annotation = flag
            view.configure(kind: flag.kind)
            return view
        }
    }

    private enum OverlayKind: String {
        case fullRoute
    }
}

// MARK: - ProgressRouteOverlay

/// web 版 buildProgressRouteGeoJson に対応するカスタムオーバーレイ。
/// traveled[0...lastReachedIndex] + runnerCoord(tip) + runnerDot を 1 つの draw() で描画する。
/// NSLock でスレッドセーフ (MapKit は draw を バックグラウンドスレッドで呼ぶ)。
final class ProgressRouteOverlay: NSObject, MKOverlay {
    private let lock = NSLock()
    private var _traveledCoords: [CLLocationCoordinate2D] = []
    private var _runnerCoord: CLLocationCoordinate2D?
    private var _strokeColor: UIColor = .systemYellow

    private let _boundingMapRect: MKMapRect

    init(fullBoundingRect: MKMapRect) {
        // ルート全体の bounding rect + 余白を固定値として保持。
        // ランナーは常にルート上にあるためこの rect で十分。
        _boundingMapRect = fullBoundingRect.insetBy(dx: -5000, dy: -5000)
    }

    func update(traveledCoords: [CLLocationCoordinate2D],
                runnerCoord: CLLocationCoordinate2D?,
                strokeColor: UIColor) {
        lock.lock()
        _traveledCoords = traveledCoords
        _runnerCoord = runnerCoord
        _strokeColor = strokeColor
        lock.unlock()
    }

    /// draw() スレッドからスナップショットを取得。
    func snapshot() -> ([CLLocationCoordinate2D], CLLocationCoordinate2D?, UIColor) {
        lock.lock()
        defer { lock.unlock() }
        return (_traveledCoords, _runnerCoord, _strokeColor)
    }

    var coordinate: CLLocationCoordinate2D {
        lock.lock(); defer { lock.unlock() }
        return _traveledCoords.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    var boundingMapRect: MKMapRect { _boundingMapRect }
}

// MARK: - ProgressRouteRenderer

/// ProgressRouteOverlay の描画ロジック (走破ラインのみ)。
/// ドットは PositionAnnotationView (MKAnnotationView) がスクリーン空間で描画する。
final class ProgressRouteRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ProgressRouteOverlay else { return }
        let (traveled, runner, strokeColor) = overlay.snapshot()

        var coords = traveled
        if let r = runner { coords.append(r) }
        guard coords.count >= 2 else { return }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(5 / zoomScale)
        context.setStrokeColor(strokeColor.cgColor)

        let firstPt = point(for: MKMapPoint(coords[0]))
        context.move(to: firstPt)
        for coord in coords.dropFirst() {
            context.addLine(to: point(for: MKMapPoint(coord)))
        }
        context.strokePath()
    }
}

// MARK: - Runner Annotation (screen-space dot)

/// ランナー現在位置アノテーション。coordinate を @objc dynamic にして差し替え移動させる。
final class PositionAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let dotColor: UIColor
    init(coordinate: CLLocationCoordinate2D, dotColor: UIColor) {
        self.coordinate = coordinate
        self.dotColor = dotColor
    }
}

/// MKAnnotationView でスクリーン空間に描画するため pitch に関係なく浮いて見える。
/// CALayer.shadowRadius でグロー、白ボーダーで球体感を出す。
final class PositionAnnotationView: MKAnnotationView {
    private let dot = CALayer()
    private let border = CALayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let size: CGFloat = 18
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        centerOffset = .zero
        backgroundColor = .clear

        dot.frame = bounds
        dot.cornerRadius = size / 2
        dot.shadowOpacity = 0.9
        dot.shadowRadius = 8
        dot.shadowOffset = .zero
        layer.addSublayer(dot)

        border.frame = bounds
        border.cornerRadius = size / 2
        // ランナードットの輪郭。Dark では白、Light では黒に自動切替 (UIColor.label)。
        border.borderColor = UIColor.label.cgColor
        border.borderWidth = 2.5
        border.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(border)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(color: UIColor) {
        dot.backgroundColor = color.cgColor
        dot.shadowColor = color.cgColor
    }
}

// MARK: - Flag Annotations

final class FlagAnnotation: NSObject, MKAnnotation {
    enum Kind: String { case start, finish }
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
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
