#if canImport(UIKit)
import SwiftUI
import MapKit
import UIKit

/// 高頻度更新でも MKPolyline が消失しない MKMapView 直叩きラッパー。
///
/// SwiftUI 標準の `Map` + `MapPolyline` は ContentBuilder の毎フレーム再評価で
/// 走破ライン (>= 数百点) が消えるバグ的挙動を起こしたため、UIKit 経由で MKMapView
/// を直接運用する。
///
/// 設計方針:
/// - 全体ルート (薄い線) は init 時に 1 度だけ MKPolyline を作って固定する
/// - 走破ラインは `traveledIndex` が動いた時だけ MKPolyline を作り直す
/// - 末端ヒゲ (直近トラックポイント → 補間中の現在位置) は毎フレーム作り直すが 2 点のみ
/// - 走者マーカーは MKAnnotation の `coordinate` を更新して移動。再追加しない
/// - カメラは smoothDamp 済みの値が来るので `setCamera(_:animated:)` を毎フレーム呼ぶ
struct FlythroughMapView: UIViewRepresentable {

    let allCoords: [CLLocationCoordinate2D]
    /// 全トラックポイントの座標配列。走破ラインを切り出すのに使う。
    let trackPointCoords: [CLLocationCoordinate2D]
    /// 走破済み区間を切り出す末尾 index。-1 や前回値と同じなら走破ラインは更新しない。
    let traveledIndex: Int
    /// 末端ヒゲ。`[直近トラックポイント, 現在の補間位置]` の 2 点固定。
    let tailCoords: [CLLocationCoordinate2D]?
    /// ランナー現在位置。
    let runnerCoord: CLLocationCoordinate2D?
    /// カメラ姿勢。followMode 中は呼び出し元で smoothDamp 済み。
    let camera: MKMapCamera
    /// MapKit Configuration。マップスタイル設定から組み立てて渡す。
    let configuration: MKMapConfiguration
    /// 走破ライン色。
    let strokeColor: UIColor
    /// 再生中フラグ。マーカーのパルスアニメ on/off に使う。
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsScale = false
        map.showsUserLocation = false
        map.isPitchEnabled = false       // フライスルー中はジェスチャ不要
        map.isRotateEnabled = false
        map.isZoomEnabled = false
        map.isScrollEnabled = false

        // 全体ルート (一度だけ追加、不変)。
        if allCoords.count >= 2 {
            let poly = MKPolyline(coordinates: allCoords, count: allCoords.count)
            poly.title = OverlayKind.full.rawValue
            map.addOverlay(poly, level: .aboveRoads)
            context.coordinator.fullPolyline = poly
        }

        // スタート / フィニッシュ (一度だけ追加、不変)。
        if let first = allCoords.first {
            let a = FlagAnnotation(coordinate: first, kind: .start)
            map.addAnnotation(a)
            context.coordinator.startAnnotation = a
        }
        if allCoords.count > 1, let last = allCoords.last {
            let a = FlagAnnotation(coordinate: last, kind: .finish)
            map.addAnnotation(a)
            context.coordinator.finishAnnotation = a
        }

        // ランナーは座標確定してから追加。
        if let runner = runnerCoord {
            let a = RunnerAnnotation(coordinate: runner)
            map.addAnnotation(a)
            context.coordinator.runnerAnnotation = a
        }

        map.setCamera(camera, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coord = context.coordinator

        // Configuration が変わっていたら更新。
        if !areConfigurationsEqual(map.preferredConfiguration, configuration) {
            map.preferredConfiguration = configuration
        }

        // 走破ライン: index が動いた時だけ作り直す。
        if traveledIndex != coord.lastTraveledIndex {
            if let old = coord.traveledPolyline {
                map.removeOverlay(old)
                coord.traveledPolyline = nil
            }
            if traveledIndex >= 1, traveledIndex < trackPointCoords.count {
                let slice = Array(trackPointCoords[0...traveledIndex])
                let poly = MKPolyline(coordinates: slice, count: slice.count)
                poly.title = OverlayKind.traveled.rawValue
                map.addOverlay(poly, level: .aboveRoads)
                coord.traveledPolyline = poly
            }
            coord.lastTraveledIndex = traveledIndex
        }

        // 末端ヒゲ: 毎フレーム作り直す (2 点しかないので軽い)。
        if let old = coord.tailPolyline {
            map.removeOverlay(old)
            coord.tailPolyline = nil
        }
        if let tail = tailCoords, tail.count == 2 {
            let poly = MKPolyline(coordinates: tail, count: tail.count)
            poly.title = OverlayKind.tail.rawValue
            map.addOverlay(poly, level: .aboveRoads)
            coord.tailPolyline = poly
        }

        // ランナーマーカー: 既存の annotation の coordinate を差し替えるだけ。
        // 再追加すると毎回 viewFor が呼ばれてビュー再生成 → アニメが切れる。
        if let runner = runnerCoord {
            if let existing = coord.runnerAnnotation {
                if !coordinatesAreEqual(existing.coordinate, runner) {
                    existing.coordinate = runner
                }
            } else {
                let a = RunnerAnnotation(coordinate: runner)
                map.addAnnotation(a)
                coord.runnerAnnotation = a
            }
        }

        // パルスアニメは isPlaying と同期。
        coord.runnerAnnotation?.isPlaying = isPlaying
        if let view = coord.runnerAnnotation.flatMap({ map.view(for: $0) }) as? RunnerAnnotationView {
            view.setPlaying(isPlaying)
        }

        // 色変更にも追従 (race カテゴリ変更などで)。
        if coord.strokeColor != strokeColor {
            coord.strokeColor = strokeColor
            // 既存 renderer の色を直接書き換える。MKMapView は overlay 単位で renderer を保持。
            for overlay in map.overlays {
                if let renderer = map.renderer(for: overlay) as? MKPolylineRenderer,
                   let title = (overlay as? MKPolyline)?.title,
                   title == OverlayKind.traveled.rawValue || title == OverlayKind.tail.rawValue {
                    renderer.strokeColor = strokeColor
                    renderer.setNeedsDisplay()
                }
            }
        }

        // カメラ更新。smoothDamp で連続値が来るので animated: false。
        map.setCamera(camera, animated: false)
    }

    private func areConfigurationsEqual(_ a: MKMapConfiguration, _ b: MKMapConfiguration) -> Bool {
        // Configuration は値型でなく Equatable でもないので型一致のみで判定。
        // 実用上は色モード切替くらいしか動かないので十分。
        type(of: a) == type(of: b)
    }

    private func coordinatesAreEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var fullPolyline: MKPolyline?
        var traveledPolyline: MKPolyline?
        var tailPolyline: MKPolyline?
        var lastTraveledIndex: Int = -1
        var runnerAnnotation: RunnerAnnotation?
        var startAnnotation: FlagAnnotation?
        var finishAnnotation: FlagAnnotation?
        var strokeColor: UIColor = .systemYellow

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: polyline)
            r.lineCap = .round
            r.lineJoin = .round
            switch polyline.title {
            case OverlayKind.full.rawValue:
                r.strokeColor = UIColor.white.withAlphaComponent(0.25)
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
            if let runner = annotation as? RunnerAnnotation {
                let id = "runner"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? RunnerAnnotationView)
                    ?? RunnerAnnotationView(annotation: runner, reuseIdentifier: id)
                view.annotation = runner
                view.setPlaying(runner.isPlaying)
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

/// ランナー (現在位置) アノテーション。座標を `var` にして coordinate 更新で移動させる。
final class RunnerAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var isPlaying: Bool = true
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

/// スタート / フィニッシュアノテーション。
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

final class RunnerAnnotationView: MKAnnotationView {
    private let outerCircle = CALayer()
    private let innerCircle = CALayer()
    private let icon = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        centerOffset = .zero
        backgroundColor = .clear

        // 黄色シャドウ + 黄丸
        let glow = CALayer()
        glow.frame = bounds.insetBy(dx: -4, dy: -4)
        glow.cornerRadius = glow.bounds.width / 2
        glow.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.35).cgColor
        glow.shadowColor = UIColor.systemYellow.cgColor
        glow.shadowOpacity = 0.6
        glow.shadowRadius = 10
        glow.shadowOffset = .zero
        layer.addSublayer(glow)

        outerCircle.frame = bounds
        outerCircle.cornerRadius = bounds.width / 2
        outerCircle.backgroundColor = UIColor.systemYellow.cgColor
        layer.addSublayer(outerCircle)

        innerCircle.frame = bounds
        innerCircle.cornerRadius = bounds.width / 2
        innerCircle.borderColor = UIColor.white.cgColor
        innerCircle.borderWidth = 3
        innerCircle.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(innerCircle)

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        icon.image = UIImage(systemName: "figure.run", withConfiguration: cfg)
        icon.tintColor = .black
        icon.contentMode = .scaleAspectFit
        icon.frame = bounds
        addSubview(icon)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func setPlaying(_ playing: Bool) {
        let key = "pulse"
        if playing {
            guard layer.animation(forKey: key) == nil else { return }
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 1.0
            anim.toValue = 1.12
            anim.duration = 0.6
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: key)
        } else {
            layer.removeAnimation(forKey: key)
        }
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
            // RaceCategory.tenK のピンカラーは Color.cat10K。MKMapView は CGColor 必須なので
            // よく使う緑系を直接指定する。元のSwiftUIで .cat10K (緑系) なのでそれに揃える。
            bg.backgroundColor = UIColor.systemGreen.cgColor
        case .finish:
            icon.image = UIImage(systemName: "flag.fill", withConfiguration: cfg)
            bg.backgroundColor = UIColor.systemRed.cgColor
        }
    }
}

// MARK: - MapStyleSettings → MKMapConfiguration

extension MapStyleSettings {
    /// MKMapView 用の `MKMapConfiguration` を組み立てる。
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
