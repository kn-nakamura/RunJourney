import SwiftUI
import MapKit

/// ルートフライスルー（地図上でルートをアニメーション再生）。
/// - フォローモード: 現在位置を中心にカメラが追跡（look-ahead で進行方向を向く）
/// - 全体モード: 静止カメラでルート全体を俯瞰
struct RouteFlythruView: View {
    @Bindable var result: RaceResult
    @Environment(\.dismiss) private var dismiss

    @State private var controller: PlaybackController
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var followMode: Bool = true
    @State private var lastCameraUpdateAt: CFTimeInterval = 0

    // MKMapView 直叩きパス (iOS/visionOS) で使うカメラ。SwiftUI Map は使わない。
    @State private var mkCamera: MKMapCamera = MKMapCamera()

    // smoothDamp の状態。velocity を呼び出し間で永続化することで初めて慣性が効く。
    // 元の実装は velocity がローカル変数で毎フレーム 0 リセットされていたため
    // smoothDamp ではなく単なる「指数平滑」として機能していた。
    @State private var smoothedHeading: Double = 0
    @State private var headingVelocity: Double = 0
    @State private var smoothedLat: Double = 0
    @State private var smoothedLng: Double = 0
    @State private var latVelocity: Double = 0
    @State private var lngVelocity: Double = 0
    @State private var hasInitializedSmoothing: Bool = false

    // Map タブで設定したマップ・ピンスタイルをそのままここでも使う。
    // 同じ AppStorage キーを参照するので自動的に同期する。
    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    /// 元のルート全体（背景polylineに使う）
    private let allCoords: [CLLocationCoordinate2D]
    /// 全トラックポイントの座標配列。MKMapView 側で走破区間を切り出すのに使う。
    private let trackPointCoords: [CLLocationCoordinate2D]
    /// 距離プロファイルから決まったカメラ姿勢・追従応答・先読み時間。
    private let cameraProfile: FollowCameraProfile

    init(result: RaceResult) {
        self.result = result
        let pts = result.trackPoints
        self.allCoords = pts.map(\.coordinate)
        self.trackPointCoords = self.allCoords  // 同じ配列を別名で保持して用途を明示
        let totalDistKm = (pts.last?.distanceM ?? 0) / 1000
        self.cameraProfile = PlaybackMath.followCameraProfile(distanceKm: totalDistKm)
        self._controller = State(initialValue: PlaybackController(trackPoints: pts))
    }

    var body: some View {
        ZStack {
            mapLayer
            VStack {
                HStack {
                    Spacer()
#if os(iOS)
                    RecordButton(
                        onRecordingWillStart: {
                            // 録画開始時はそのままプレイ可能（ユーザーが play で開始する想定）
                        },
                        onRecordingDidStop: {
                            // 録画停止と同時にプレイバックも停止 → カメラ追従更新が止まり
                            // RPPreviewViewController と裏側の Map がぶつからない
                            controller.pause()
                        }
                    )
                    .padding(.trailing, 14)
                    .padding(.top, 6)
#endif
                }
                Spacer()
                PlaybackHUD(controller: controller, race: result.race)
                PlaybackControls(controller: controller, followMode: $followMode)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(Color.bgPrimary)
        .navigationTitle(result.race?.name ?? "再生")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    followMode.toggle()
                    if !followMode {
                        cameraPosition = overviewCameraPosition()
#if canImport(UIKit)
                        mkCamera = overviewMKCamera()
#endif
                    } else {
                        // 全体表示から戻ってきた時は smoothDamp の状態を再シードする。
                        hasInitializedSmoothing = false
                        advanceSmoothing(dt: 1.0 / 60.0)
                        cameraPosition = makeMapCameraPosition()
#if canImport(UIKit)
                        mkCamera = makeMKCamera()
#endif
                    }
                } label: {
                    Image(systemName: followMode ? "scope" : "map")
                        .imageScale(.large)
                }
            }
        }
        .onAppear {
            // 初期カメラ。smoothDamp の状態をシードしてから両系統に反映する。
            advanceSmoothing(dt: 1.0 / 60.0)
            if followMode {
                cameraPosition = makeMapCameraPosition()
#if canImport(UIKit)
                mkCamera = makeMKCamera()
#endif
            } else {
                cameraPosition = overviewCameraPosition()
#if canImport(UIKit)
                mkCamera = overviewMKCamera()
#endif
            }
        }
        .onDisappear {
            // 画面を離れたら再生を止めて Timer も invalidate する。
            // 戻って来たときに自動で再開はしない（明示的に play を押し直す）。
            controller.pause()
        }
        .onChange(of: controller.currentTime) { _, _ in
            updateCameraIfNeeded()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        ColorSchemeOverride(scheme: mapSettings.preferredColorScheme) {
#if canImport(UIKit)
            // iOS/visionOS: SwiftUI Map の MapPolyline は >= 数百点を 120Hz で更新すると
            // 描画スキップで線が消えるため、MKMapView を直接使う。
            FlythroughMapView(
                allCoords: allCoords,
                trackPointCoords: trackPointCoords,
                traveledIndex: controller.lastReachedIndexValue,
                tailCoords: controller.traveledTailSegment,
                runnerCoord: controller.currentPoint?.coordinate,
                camera: mkCamera,
                configuration: mapSettings.mapConfiguration,
                strokeColor: UIColor(result.race?.category.pinColor ?? .accentPrimary),
                isPlaying: controller.isPlaying
            )
#else
            // macOS フォールバック (SwiftUI Map)。再生頻度が低ければ問題なく動く。
            Map(position: $cameraPosition) {
                if allCoords.count >= 2 {
                    MapPolyline(coordinates: allCoords)
                        .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                let traveled = controller.traveledPoints.map(\.coordinate)
                let strokeColor = result.race?.category.pinColor ?? .accentPrimary
                let strokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                if traveled.count >= 2 {
                    MapPolyline(coordinates: traveled)
                        .stroke(strokeColor, style: strokeStyle)
                }
                if let tail = controller.traveledTailSegment {
                    MapPolyline(coordinates: tail)
                        .stroke(strokeColor, style: strokeStyle)
                }
                if let p = controller.currentPoint {
                    Annotation("", coordinate: p.coordinate, anchor: .center) {
                        runnerMarker
                    }
                }
                if let first = allCoords.first {
                    Annotation("Start", coordinate: first) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.white).padding(5)
                            .background(Color.cat10K, in: Circle())
                    }
                }
                if let last = allCoords.last, allCoords.count > 1 {
                    Annotation("Finish", coordinate: last) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.white).padding(5)
                            .background(Color.catFullMarathon, in: Circle())
                    }
                }
            }
            .mapStyle(mapSettings.mapStyle)
#endif
        }
        .ignoresSafeArea(edges: .top)
    }

    private var runnerMarker: some View {
        ZStack {
            Circle()
                .fill(Color.accentPrimary)
                .frame(width: 22, height: 22)
                .shadow(color: .accentPrimary.opacity(0.7), radius: 8)
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 22, height: 22)
            Image(systemName: "figure.run")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
        }
        .scaleEffect(controller.isPlaying ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: controller.isPlaying)
    }

    // MARK: - Camera

    private func updateCameraIfNeeded() {
        guard followMode else { return }
        let now = CACurrentMediaTime()
        let dt = lastCameraUpdateAt == 0 ? (1.0 / 120.0) : (now - lastCameraUpdateAt)
        lastCameraUpdateAt = now
        let safeDt = max(dt, 1.0 / 240.0)
        // smoothDamp 状態を進める。両 SwiftUI/UIKit パスで共通。
        advanceSmoothing(dt: safeDt)
#if canImport(UIKit)
        mkCamera = makeMKCamera()
#else
        cameraPosition = makeMapCameraPosition()
#endif
    }

    /// smoothDamp の internal state を `dt` 秒進める。
    private func advanceSmoothing(dt: Double) {
        guard let cur = controller.currentPoint else { return }

        if !hasInitializedSmoothing {
            smoothedLat = cur.coordinate.latitude
            smoothedLng = cur.coordinate.longitude
            if let lookAhead = controller.lookAheadPoint(sec: cameraProfile.lookAheadSec),
               lookAhead.id != cur.id {
                smoothedHeading = PlaybackMath.bearingDegrees(
                    from: cur.coordinate,
                    to: lookAhead.coordinate
                )
            }
            hasInitializedSmoothing = true
        }

        let lookAhead = controller.lookAheadPoint(sec: cameraProfile.lookAheadSec)
        let rawHeading: Double
        if let lookAhead, lookAhead.id != cur.id {
            rawHeading = PlaybackMath.bearingDegrees(from: cur.coordinate, to: lookAhead.coordinate)
        } else {
            rawHeading = smoothedHeading
        }

        smoothedHeading = AngleMath.smoothDampAngle(
            from: smoothedHeading,
            to: rawHeading,
            velocity: &headingVelocity,
            smoothTime: cameraProfile.bearingResponseSec,
            dt: dt
        )
        smoothedLat = AngleMath.smoothDamp(
            from: smoothedLat,
            to: cur.coordinate.latitude,
            velocity: &latVelocity,
            smoothTime: cameraProfile.centerResponseSec,
            dt: dt
        )
        smoothedLng = AngleMath.smoothDamp(
            from: smoothedLng,
            to: cur.coordinate.longitude,
            velocity: &lngVelocity,
            smoothTime: cameraProfile.centerResponseSec,
            dt: dt
        )
    }

#if canImport(UIKit)
    /// UIKit 経路: smoothDamp 済みの値から MKMapCamera を組み立てる。
    private func makeMKCamera() -> MKMapCamera {
        let cam = MKMapCamera()
        cam.centerCoordinate = CLLocationCoordinate2D(
            latitude: smoothedLat,
            longitude: smoothedLng
        )
        cam.centerCoordinateDistance = cameraProfile.distance
        cam.heading = smoothedHeading
        cam.pitch = cameraProfile.pitch
        return cam
    }
#endif

    /// SwiftUI Map 経路 (macOS など): MapCameraPosition を返す。
    private func makeMapCameraPosition() -> MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLng),
            distance: cameraProfile.distance,
            heading: smoothedHeading,
            pitch: cameraProfile.pitch
        ))
    }

    /// 旧コードからの呼び出し互換。toolbar や onAppear で使う。
    private func followCameraPosition(dt: Double = 1.0 / 60.0) -> MapCameraPosition {
        advanceSmoothing(dt: dt)
        return makeMapCameraPosition()
    }

    private func overviewCameraPosition() -> MapCameraPosition {
        guard allCoords.count >= 2 else { return .automatic }
        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(lats.max()! - lats.min()!, 0.005) * 1.4,
            longitudeDelta: max(lngs.max()! - lngs.min()!, 0.005) * 1.4
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

#if canImport(UIKit)
    /// UIKit 経路の俯瞰カメラ。距離は緯度経度幅から大雑把に算出。
    private func overviewMKCamera() -> MKMapCamera {
        let cam = MKMapCamera()
        guard allCoords.count >= 2 else { return cam }
        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        // 緯度 1° ≒ 111km。コース全長 + マージンが画面に収まる距離。
        let latSpan = max(lats.max()! - lats.min()!, 0.005)
        let lngSpan = max(lngs.max()! - lngs.min()!, 0.005)
        let approxSpanM = max(latSpan, lngSpan) * 111_000
        cam.centerCoordinate = center
        cam.centerCoordinateDistance = approxSpanM * 1.6
        cam.pitch = 0
        cam.heading = 0
        return cam
    }
#endif
}
