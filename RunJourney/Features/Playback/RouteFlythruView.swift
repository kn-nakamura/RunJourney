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
    @State private var lastCameraUpdateAt: Date = .distantPast
    @State private var smoothedHeading: Double = 0

    /// 元のルート全体（背景polylineに使う）
    private let allCoords: [CLLocationCoordinate2D]
    /// 推奨カメラ距離（ルート長から計算）
    private let cameraDistance: Double

    init(result: RaceResult) {
        self.result = result
        let pts = result.trackPoints
        self.allCoords = pts.map(\.coordinate)
        let totalDist = pts.last?.distanceM ?? 0
        self.cameraDistance = PlaybackMath.recommendedCameraDistance(totalDistanceM: totalDist)
        self._controller = State(initialValue: PlaybackController(trackPoints: pts))
    }

    var body: some View {
        ZStack {
            mapLayer
            VStack {
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
                    }
                } label: {
                    Image(systemName: followMode ? "scope" : "map")
                        .imageScale(.large)
                }
            }
        }
        .onAppear {
            // 初期カメラ
            cameraPosition = followMode ? followCameraPosition() : overviewCameraPosition()
        }
        .onChange(of: controller.currentTime) { _, _ in
            updateCameraIfNeeded()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            // 全体ルート（薄い線）
            if allCoords.count >= 2 {
                MapPolyline(coordinates: allCoords)
                    .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // 走破済み（強調）
            let traveled = controller.traveledPoints.map(\.coordinate)
            if traveled.count >= 2 {
                MapPolyline(coordinates: traveled)
                    .stroke(
                        result.race?.category.pinColor ?? .accentPrimary,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }
            // 現在位置マーカー
            if let p = controller.currentPoint {
                Annotation("", coordinate: p.coordinate, anchor: .center) {
                    runnerMarker
                }
            }
            // スタート/フィニッシュ
            if let first = allCoords.first {
                Annotation("Start", coordinate: first) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.cat10K, in: Circle())
                }
            }
            if let last = allCoords.last, allCoords.count > 1 {
                Annotation("Finish", coordinate: last) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.catFullMarathon, in: Circle())
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
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
        // カメラ更新は最大10Hzに絞る（Mapの再描画コスト削減）
        let now = Date.now
        guard now.timeIntervalSince(lastCameraUpdateAt) > 0.1 else { return }
        lastCameraUpdateAt = now
        withAnimation(.linear(duration: 0.1)) {
            cameraPosition = followCameraPosition()
        }
    }

    private func followCameraPosition() -> MapCameraPosition {
        guard let cur = controller.currentPoint else { return .automatic }
        let target = controller.lookAheadPoint
        var heading: Double
        if let target, target.id != cur.id {
            heading = PlaybackMath.bearingDegrees(from: cur.coordinate, to: target.coordinate)
        } else {
            heading = smoothedHeading
        }
        // smoothDamp で滑らかに
        var velocity = 0.0
        smoothedHeading = AngleMath.smoothDampAngle(
            from: smoothedHeading, to: heading, velocity: &velocity, smoothTime: 0.5, dt: 0.1
        )
        return .camera(MapCamera(
            centerCoordinate: cur.coordinate,
            distance: cameraDistance,
            heading: smoothedHeading,
            pitch: 60
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
}
