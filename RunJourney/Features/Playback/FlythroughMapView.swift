#if canImport(UIKit)
import SwiftUI
import MapKit
import UIKit

/// 高頻度更新でも軌跡が正確に表示される MKMapView ラッパー。
///
/// 設計方針 (marathon-record-app の buildProgressRouteGeoJson + setData 方式を移植):
/// - 全体ルート (ダークグレー MKPolyline) は init 時に 1 度だけ追加、不変
/// - 走破ライン先端とランナードットは ProgressRouteOverlay (カスタム MKOverlay) で管理
///   → 同一 draw() 内でライン末端 = runnerCoord、ドット中心 = runnerCoord を描画するため
///      物理的にズレが生じない (web 版 progressSource / markerSource が同フレームで確定する設計と等価)
/// - MKPolyline の add/remove を使わないため MapKit レンダリングをブロックしない
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

        map.setCamera(camera, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coord = context.coordinator
        coord.onUserInteraction = onUserInteraction

        if !areConfigurationsEqual(map.preferredConfiguration, configuration) {
            map.preferredConfiguration = configuration
        }

        // 走破データ更新: web 版 buildProgressRouteGeoJson と同様に
        //   traveled[0...lastReachedIndex] + runnerCoord(tip) を 1 本のラインで表す
        if let overlay = coord.progressOverlay {
            let endIdx = min(traveledIndex, trackPointCoords.count - 1)
            let traveled: [CLLocationCoordinate2D] = endIdx >= 0
                ? Array(trackPointCoords[0...endIdx])
                : []
            overlay.update(traveledCoords: traveled, runnerCoord: runnerCoord, strokeColor: strokeColor)
            if let renderer = map.renderer(for: overlay) as? ProgressRouteRenderer {
                renderer.setNeedsDisplay()
            }
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
        var wasInOverview: Bool = false
        var onUserInteraction: (() -> Void)?

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
                r.strokeColor = UIColor(red: 58/255, green: 58/255, blue: 74/255, alpha: 0.85)
                r.lineWidth = 4
            } else {
                r.strokeColor = .white
                r.lineWidth = 4
            }
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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

/// ProgressRouteOverlay の描画ロジック。
/// ライン先端 (runnerCoord) とドット中心 (runnerCoord) が同一 draw() 内で確定するため
/// marathon-record-app の progressSource / markerSource を同フレームで setData する設計と等価。
final class ProgressRouteRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ProgressRouteOverlay else { return }
        let (traveled, runner, strokeColor) = overlay.snapshot()

        // traveled[0...n] + tip (runner) で 1 本のラインを構成
        var coords = traveled
        if let r = runner { coords.append(r) }
        guard coords.count >= 2 else { return }

        // 走破ライン
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

        // ランナードット: ライン先端 = runnerCoord と完全一致
        guard let runner else { return }
        let runnerPt = point(for: MKMapPoint(runner))
        let dotR = 8.0 / zoomScale

        // 黄色グロー: CGContext.setShadow は MapKit タイルレンダラーで無効なため
        // 半透明同心円を重ねてソフトグローを再現する
        let glowSteps: [(radius: Double, alpha: Double)] = [
            (20, 0.12), (16, 0.20), (12, 0.32), (10, 0.48)
        ]
        for step in glowSteps {
            let r = step.radius / zoomScale
            context.setFillColor(UIColor.systemYellow.withAlphaComponent(step.alpha).cgColor)
            context.fillEllipse(in: CGRect(x: runnerPt.x - r, y: runnerPt.y - r,
                                           width: r * 2, height: r * 2))
        }

        // 黄色ドット本体
        context.setFillColor(UIColor.systemYellow.cgColor)
        context.fillEllipse(in: CGRect(x: runnerPt.x - dotR, y: runnerPt.y - dotR,
                                       width: dotR * 2, height: dotR * 2))

        // 白ボーダー
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2 / zoomScale)
        context.addEllipse(in: CGRect(x: runnerPt.x - dotR, y: runnerPt.y - dotR,
                                      width: dotR * 2, height: dotR * 2))
        context.strokePath()
    }
}

// MARK: - Annotations (Flag only)

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
