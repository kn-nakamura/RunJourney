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

    // smoothDamp の状態。velocity を呼び出し間で永続化することで慣性が効く。
    @State private var smoothedHeading: Double = 0
    @State private var headingVelocity: Double = 0
    @State private var smoothedLat: Double = 0
    @State private var smoothedLng: Double = 0
    @State private var latVelocity: Double = 0
    @State private var lngVelocity: Double = 0
    @State private var hasInitializedSmoothing: Bool = false
    // deadband 用: 前フレームの「生ベアリング目標」。ブレンド済みの値を保持。
    @State private var blendedBearingTarget: Double = 0

    // ユーザ上書きカメラ値 (nil = プロファイル自動)
    @State private var userPitch: Double? = nil
    @State private var userDistance: Double? = nil
    @State private var userCenterResponse: Double? = nil
    @State private var userBearingResponse: Double? = nil

    // UI 状態
    @State private var showSettings: Bool = false
    @State private var showExportSheet: Bool = false

    // Map タブで設定したマップ・ピンスタイルをそのままここでも使う。
    @StoredMapStyleSettings private var mapSettings
    @StoredPinSettings private var pinSettings

    /// 元のルート全体（背景polylineに使う）
    private let allCoords: [CLLocationCoordinate2D]
    private let trackPointCoords: [CLLocationCoordinate2D]
    /// 距離プロファイルから決まったカメラ姿勢・追従応答・先読み時間。
    private let cameraProfile: FollowCameraProfile

    init(result: RaceResult) {
        self.result = result
        let pts = result.trackPoints
        self.allCoords = pts.map(\.coordinate)
        self.trackPointCoords = self.allCoords
        let totalDistKm = (pts.last?.distanceM ?? 0) / 1000
        self.cameraProfile = PlaybackMath.followCameraProfile(distanceKm: totalDistKm)
        self._controller = State(initialValue: PlaybackController(trackPoints: pts))
    }

    // MARK: - Effective camera params (user override or auto profile)

    private var effectivePitch: Double { userPitch ?? cameraProfile.pitch }
    private var effectiveDistance: Double { userDistance ?? cameraProfile.distance }
    private var effectiveCenterResp: Double { userCenterResponse ?? cameraProfile.centerResponseSec }
    private var effectiveBearingResp: Double { userBearingResponse ?? cameraProfile.bearingResponseSec }

    var body: some View {
        ZStack {
            mapLayer
            VStack(spacing: 6) {
                // Settings パネル（ツールバー直下、スライドイン）
                if showSettings {
                    PlaybackSettingsPanel(
                        controller: controller,
                        userPitch: $userPitch,
                        userDistance: $userDistance,
                        userCenterResponse: $userCenterResponse,
                        userBearingResponse: $userBearingResponse,
                        profilePitch: cameraProfile.pitch,
                        profileDistance: cameraProfile.distance,
                        profileCenterResponse: cameraProfile.centerResponseSec,
                        profileBearingResponse: cameraProfile.bearingResponseSec
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                PlaybackHUD(controller: controller, race: result.race)
                PlaybackControls(controller: controller) {
                    // Rewind: smoothDamp 状態をリセット
                    hasInitializedSmoothing = false
                    blendedBearingTarget = smoothedHeading
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .animation(.easeInOut(duration: 0.22), value: showSettings)
        }
        .background(Color.bgPrimary)
        .navigationTitle(result.race?.name ?? "Playback")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Follow / Overview セグメントコントロール
                HStack(spacing: 0) {
                    modeButton(label: "Follow", isActive: followMode) {
                        activateFollowMode()
                    }
                    modeButton(label: "Overview", isActive: !followMode) {
                        activateOverviewMode()
                    }
                }
                .background(Color.bgSecondary, in: Capsule())

                // Settings
                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Image(systemName: "gearshape")
                        .symbolVariant(showSettings ? .fill : .none)
                        .foregroundStyle(showSettings ? Color.accentPrimary : .primary)
                }

                // Export
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(controller: controller)
        }
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
        // 再生開始時に自動でフォローモードへ遷移
        .onChange(of: controller.isPlaying) { _, isPlaying in
            if isPlaying, !followMode {
                activateFollowMode()
            }
        }
    }

    // MARK: - Toolbar helpers

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
        followMode = true
        hasInitializedSmoothing = false
        advanceSmoothing(dt: 1.0 / 60.0)
        applyCamera()
    }

    private func activateOverviewMode() {
        followMode = false
        showSettings = false
        cameraPosition = overviewCameraPosition()
#if canImport(UIKit)
        mkCamera = overviewMKCamera()
#endif
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        ColorSchemeOverride(scheme: mapSettings.preferredColorScheme) {
#if canImport(UIKit)
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
        advanceSmoothing(dt: safeDt)
        applyCamera()
    }

    private func applyCamera() {
        if followMode {
#if canImport(UIKit)
            mkCamera = makeMKCamera()
#else
            cameraPosition = makeMapCameraPosition()
#endif
        }
    }

    /// smoothDamp の internal state を `dt` 秒進める（デッドバンド付き）。
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

        // --- Bearing deadband / soft-zone ---
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
            // ブレンド分だけ目標を更新してから smoothDamp に渡す
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

        // --- Position deadband / soft-zone ---
        let dLat = cur.coordinate.latitude - smoothedLat
        let dLng = cur.coordinate.longitude - smoothedLng
        // 緯度差を概算メートルに変換して deadband チェック
        let approxDeltaM = sqrt((dLat * 111_000) * (dLat * 111_000) + (dLng * 111_000) * (dLng * 111_000))
        let posBlend = PlaybackMath.softBlendFactor(
            delta: approxDeltaM,
            deadband: cameraProfile.centerDeadbandM,
            softZone: cameraProfile.centerSoftZoneM
        )
        let targetLat = posBlend > 0
            ? smoothedLat + dLat * posBlend
            : smoothedLat
        let targetLng = posBlend > 0
            ? smoothedLng + dLng * posBlend
            : smoothedLng

        smoothedLat = AngleMath.smoothDamp(
            from: smoothedLat,
            to: targetLat,
            velocity: &latVelocity,
            smoothTime: effectiveCenterResp,
            dt: dt
        )
        smoothedLng = AngleMath.smoothDamp(
            from: smoothedLng,
            to: targetLng,
            velocity: &lngVelocity,
            smoothTime: effectiveCenterResp,
            dt: dt
        )
    }

#if canImport(UIKit)
    private func makeMKCamera() -> MKMapCamera {
        let cam = MKMapCamera()
        cam.centerCoordinate = CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLng)
        cam.centerCoordinateDistance = effectiveDistance
        cam.heading = smoothedHeading
        cam.pitch = effectivePitch
        return cam
    }
#endif

    private func makeMapCameraPosition() -> MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: smoothedLat, longitude: smoothedLng),
            distance: effectiveDistance,
            heading: smoothedHeading,
            pitch: effectivePitch
        ))
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
    private func overviewMKCamera() -> MKMapCamera {
        let cam = MKMapCamera()
        guard allCoords.count >= 2 else { return cam }
        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
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
