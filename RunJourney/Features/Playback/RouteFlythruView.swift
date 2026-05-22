import SwiftUI
import MapKit

/// ルートフライスルー（地図上でルートをアニメーション再生）。
/// - フォローモード: 現在位置を中心にカメラが追跡（look-ahead で進行方向を向く）
/// - 全体モード: ルート全体を俯瞰。ユーザがジェスチャで自由に動かせる
struct RouteFlythruView: View {
    @Bindable var result: RaceResult
    @Environment(\.dismiss) private var dismiss

    @State private var controller: PlaybackController
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var followMode: Bool = true

    // MKMapView 直叩きパス (iOS/visionOS) で使うカメラ。
    @State private var mkCamera: MKMapCamera = MKMapCamera()

    // smoothDamp の状態。velocity を呼び出し間で永続化することで慣性が効く。
    @State private var smoothedHeading: Double = 0
    @State private var headingVelocity: Double = 0
    @State private var smoothedLat: Double = 0
    @State private var smoothedLng: Double = 0
    @State private var latVelocity: Double = 0
    @State private var lngVelocity: Double = 0
    @State private var hasInitializedSmoothing: Bool = false
    @State private var blendedBearingTarget: Double = 0
    @State private var lastCameraUpdateAt: CFTimeInterval = 0

    // ユーザ上書きカメラ値 (nil = プロファイル自動)
    /// カメラ角度 (0..180 度)。0 = 後方地面、90 = 真上、180 = 前方地面。
    @State private var userAngle: Double? = nil
    @State private var userDistance: Double? = nil
    /// 進行方向に対する yaw オフセット (-180..180 度)。+ = 右側から見る、- = 左側。
    @State private var userRotation: Double? = nil
    @State private var userCenterResponse: Double? = nil
    @State private var userBearingResponse: Double? = nil

    /// 山の高低差を擬似強調するカメラトリック設定。デフォルト High。
    @AppStorage(ElevationEmphasis.userDefaultsKey) private var elevationEmphasisRaw: String = ElevationEmphasis.high.rawValue
    private var elevationEmphasis: ElevationEmphasis {
        ElevationEmphasis(rawValue: elevationEmphasisRaw) ?? .high
    }

    // ユーザがマップを触った時刻から 2.5 秒間はカメラ制御を渡す
    @State private var userInteractionExpiresAt: CFTimeInterval = 0

    // UI 状態
    @State private var showSettings: Bool = false
    /// 画面録画 (ReplayKit) ラッパー。録画中は他のUIをフェードアウトさせるため
    /// `RecordButton` と RouteFlythruView の両方から状態を観察する。
    @State private var exporter = VideoExporter()

    private var isRecording: Bool {
        if case .recording = exporter.state { return true }
        return false
    }

    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    /// マップの light/dark をホーム画面 (RaceMapView) と統一するため、
    /// `mapSettings.colorMode` ではなくアプリ全体テーマに追従させる。
    /// `.system` のときは `colorScheme = nil` でシステム外観に追従する。
    @AppStorage(AppTheme.userDefaultsKey) private var appThemeRaw: String = AppTheme.dark.rawValue
    private var appTheme: AppTheme { AppTheme.resolve(appThemeRaw) }

    private let allCoords: [CLLocationCoordinate2D]
    private let trackPointCoords: [CLLocationCoordinate2D]
    private let totalDistanceKm: Double

    init(result: RaceResult) {
        self.result = result
        let pts = result.trackPoints
        self.allCoords = pts.map(\.coordinate)
        self.trackPointCoords = self.allCoords
        self.totalDistanceKm = (pts.last?.distanceM ?? 0) / 1000
        self._controller = State(initialValue: PlaybackController(trackPoints: pts))
    }

    // MARK: - Effective camera params

    /// Elevation emphasis 設定を含むカメラプロファイル。emphasis 変更時に再計算される。
    private var cameraProfile: FollowCameraProfile {
        PlaybackMath.followCameraProfile(distanceKm: totalDistanceKm, emphasis: elevationEmphasis)
    }
    private var effectiveAngle: Double { userAngle ?? cameraProfile.angle }
    private var effectiveDistance: Double { userDistance ?? cameraProfile.distance }
    private var effectiveRotation: Double { userRotation ?? 0 }
    private var effectiveCenterResp: Double { userCenterResponse ?? cameraProfile.centerResponseSec }
    private var effectiveBearingResp: Double { userBearingResponse ?? cameraProfile.bearingResponseSec }

    /// ユーザがマップを触っている (または触ってから 2.5 秒経っていない) か。
    private var isUserInteracting: Bool { CACurrentMediaTime() < userInteractionExpiresAt }

    var body: some View {
        ZStack {
            mapLayer
            VStack(spacing: 0) {
                if showSettings {
                    PlaybackSettingsPanel(
                        controller: controller,
                        userAngle: $userAngle,
                        userDistance: $userDistance,
                        userRotation: $userRotation,
                        userCenterResponse: $userCenterResponse,
                        userBearingResponse: $userBearingResponse,
                        elevationEmphasisRaw: $elevationEmphasisRaw,
                        profileAngle: cameraProfile.angle,
                        profileDistance: cameraProfile.distance,
                        profileCenterResponse: cameraProfile.centerResponseSec,
                        profileBearingResponse: cameraProfile.bearingResponseSec
                    )
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                PlaybackHUD(controller: controller, race: result.race)
                    .padding(.horizontal, 12)
                PlaybackControls(controller: controller) {
                    hasInitializedSmoothing = false
                    blendedBearingTarget = smoothedHeading
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .animation(.easeInOut(duration: 0.22), value: showSettings)
            .opacity(isRecording ? 0 : 1)
            .allowsHitTesting(!isRecording)
            .animation(.easeInOut(duration: 0.25), value: isRecording)

#if os(iOS)
            // 録画ボタン: 録画中も常時表示。ZStack の右下に固定配置する。
            RecordButton(
                exporter: exporter,
                onRecordingWillStart: {
                    controller.seek(to: 0)
                    controller.play()
                },
                onRecordingDidStop: {
                    controller.pause()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 16)
            .padding(.bottom, 32)
            .allowsHitTesting(true)
#endif
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            customHeader
                .opacity(isRecording ? 0 : 1)
                .allowsHitTesting(!isRecording)
                .animation(.easeInOut(duration: 0.25), value: isRecording)
        }
        .background(Color.bgPrimary)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
#endif
        .onAppear {
            advanceSmoothing(dt: 1.0 / 60.0)
            applyCamera()
        }
        .onDisappear {
            controller.pause()
        }
        .onChange(of: controller.currentTime) { _, _ in
            updateCameraIfNeeded()
        }
        // スライダー操作時は即時カメラ反映。再生停止中でも反応するようにする。
        // smoothing は通さず effective* 値だけで再計算するため snap 応答になる。
        .onChange(of: userAngle)    { _, _ in if followMode { applyCamera() } }
        .onChange(of: userDistance) { _, _ in if followMode { applyCamera() } }
        .onChange(of: userRotation) { _, _ in if followMode { applyCamera() } }
        .onChange(of: elevationEmphasisRaw) { _, _ in if followMode { applyCamera() } }
    }

    // MARK: - Custom header

    @ViewBuilder
    private var customHeader: some View {
        VStack(spacing: 0) {
            // Row 1: full race name (small) — pushed below the status bar / dynamic island
            Text(result.race?.name ?? "Playback")
                .appText(.bodyXs)
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 3)

            // Row 2: back + Follow/Overview + spacer + gear
            // (録画ボタンは ZStack 内の右下 overlay として配置)
            HStack(spacing: 4) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    modeButton(label: "Follow", isActive: followMode) { activateFollowMode() }
                    modeButton(label: "Overview", isActive: !followMode) { activateOverviewMode() }
                }
                .background(Color.bgSecondary, in: Capsule())

                Spacer()

                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(showSettings ? Color.accentPrimary : Color.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 4)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.15)
        }
    }

    // MARK: - Header helpers

    @ViewBuilder
    private func modeButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .appText(.bodyXs)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentPrimary : Color.clear, in: Capsule())
                .foregroundStyle(isActive ? Color.black : Color.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private func activateFollowMode() {
        userInteractionExpiresAt = 0          // ユーザ上書きを即座に解除
        followMode = true
        hasInitializedSmoothing = false       // ランナー位置から smoothDamp を再初期化
        advanceSmoothing(dt: 1.0 / 60.0)
        applyCamera()
    }

    private func activateOverviewMode() {
        followMode = false
        showSettings = false
        // カメラ設定不要 — FlythroughMapView 内で setVisibleMapRect を実行する
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        ColorSchemeOverride(scheme: appTheme.colorScheme) {
#if canImport(UIKit)
            FlythroughMapView(
                allCoords: allCoords,
                trackPointCoords: trackPointCoords,
                traveledIndex: controller.lastReachedIndexValue,
                runnerCoord: controller.currentPoint?.coordinate,
                camera: mkCamera,
                configuration: mapSettings.mapConfiguration,
                strokeColor: UIColor(result.race?.category.pinColor ?? .accentPrimary),
                isPlaying: controller.isPlaying,
                isOverview: !followMode,
                isUserInteracting: isUserInteracting,
                onUserInteraction: {
                    userInteractionExpiresAt = CACurrentMediaTime() + 2.5
                }
            )
#else
            Map(position: $cameraPosition) {
                if allCoords.count >= 2 {
                    MapPolyline(coordinates: allCoords)
                        .stroke(
                            Color(red: 58/255, green: 58/255, blue: 74/255).opacity(0.85),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
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
            }
            .mapStyle(mapSettings.mapStyle)
#endif
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Camera

    private func updateCameraIfNeeded() {
        guard followMode, !isUserInteracting else { return }
        let now = CACurrentMediaTime()
        let dt = lastCameraUpdateAt == 0 ? (1.0 / 120.0) : (now - lastCameraUpdateAt)
        lastCameraUpdateAt = now
        let safeDt = max(dt, 1.0 / 240.0)
        // 停止中のシーク操作ではスムージングをリセットしてカメラを即座にスナップさせる。
        // 再生中は smoothDamp による慣性追跡を維持する。
        if !controller.isPlaying {
            hasInitializedSmoothing = false
            latVelocity = 0
            lngVelocity = 0
            headingVelocity = 0
        }
        advanceSmoothing(dt: safeDt)
        applyCamera()
    }

    private func applyCamera() {
        guard followMode else { return }
#if canImport(UIKit)
        mkCamera = makeMKCamera()
#else
        cameraPosition = makeMapCameraPosition()
#endif
    }

    private func advanceSmoothing(dt: Double) {
        guard let cur = controller.currentPoint else { return }

        if !hasInitializedSmoothing {
            smoothedLat = cur.coordinate.latitude
            smoothedLng = cur.coordinate.longitude
            if let lookAhead = controller.lookAheadPoint(sec: cameraProfile.lookAheadSec),
               lookAhead.id != cur.id {
                let initBearing = PlaybackMath.bearingDegrees(from: cur.coordinate, to: lookAhead.coordinate)
                smoothedHeading = initBearing
                blendedBearingTarget = initBearing
            }
            hasInitializedSmoothing = true
        }

        // Bearing deadband / soft-zone
        let rawHeading: Double
        if let lookAhead = controller.lookAheadPoint(sec: cameraProfile.lookAheadSec),
           lookAhead.id != cur.id {
            rawHeading = PlaybackMath.bearingDegrees(from: cur.coordinate, to: lookAhead.coordinate)
        } else {
            rawHeading = blendedBearingTarget
        }
        let bearingDelta = AngleMath.shortestDelta(from: blendedBearingTarget, to: rawHeading)
        let bearingBlend = PlaybackMath.softBlendFactor(
            delta: bearingDelta,
            deadband: cameraProfile.bearingDeadbandDeg,
            softZone: cameraProfile.bearingSoftZoneDeg
        )
        if bearingBlend > 0 {
            blendedBearingTarget = (blendedBearingTarget + bearingDelta * bearingBlend)
                .truncatingRemainder(dividingBy: 360)
        }
        smoothedHeading = AngleMath.smoothDampAngle(
            from: smoothedHeading,
            to: blendedBearingTarget,
            velocity: &headingVelocity,
            smoothTime: effectiveBearingResp,
            dt: dt
        )

        // Position deadband / soft-zone
        let dLat = cur.coordinate.latitude - smoothedLat
        let dLng = cur.coordinate.longitude - smoothedLng
        let approxDeltaM = sqrt((dLat * 111_000) * (dLat * 111_000) + (dLng * 111_000) * (dLng * 111_000))
        let posBlend = PlaybackMath.softBlendFactor(
            delta: approxDeltaM,
            deadband: cameraProfile.centerDeadbandM,
            softZone: cameraProfile.centerSoftZoneM
        )
        let targetLat = posBlend > 0 ? smoothedLat + dLat * posBlend : smoothedLat
        let targetLng = posBlend > 0 ? smoothedLng + dLng * posBlend : smoothedLng

        smoothedLat = AngleMath.smoothDamp(
            from: smoothedLat, to: targetLat, velocity: &latVelocity,
            smoothTime: effectiveCenterResp, dt: dt
        )
        smoothedLng = AngleMath.smoothDamp(
            from: smoothedLng, to: targetLng, velocity: &lngVelocity,
            smoothTime: effectiveCenterResp, dt: dt
        )
    }

    /// userAngle (0..180) と userRotation (-180..180) を MapKit (pitch, heading) に変換。
    /// - pitch: angleToMapPitch で 0..85 にマップ
    /// - heading: 経路 bearing (smoothed) + 90超え時の 180度反転 + ユーザの yaw オフセット (snap)
    private var resolvedCameraOrientation: (pitch: Double, heading: Double) {
        let pitch = PlaybackMath.angleToMapPitch(effectiveAngle)
        let flip = PlaybackMath.headingFlip(forAngle: effectiveAngle)
        let heading = (smoothedHeading + flip + effectiveRotation + 360).truncatingRemainder(dividingBy: 360)
        return (pitch, heading)
    }

#if canImport(UIKit)
    private func makeMKCamera() -> MKMapCamera {
        let cam = MKMapCamera()
        let orient = resolvedCameraOrientation
        cam.centerCoordinate = CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLng)
        cam.centerCoordinateDistance = effectiveDistance
        cam.heading = orient.heading
        cam.pitch = orient.pitch
        return cam
    }
#endif

    private func makeMapCameraPosition() -> MapCameraPosition {
        let orient = resolvedCameraOrientation
        return .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLng),
            distance: effectiveDistance,
            heading: orient.heading,
            pitch: orient.pitch
        ))
    }

}
