import Foundation
import SwiftUI
import QuartzCore
import CoreLocation

/// ルートフライスルーの再生状態を管理する @Observable コントローラ。
/// CADisplayLink で表示同期しながら `currentTime` を進める。`speed` で時間倍率を調整。
@Observable
final class PlaybackController {

    // 入力
    let trackPoints: [TrackPoint]
    let totalDuration: TimeInterval

    // 状態
    var currentTime: TimeInterval = 0 {
        didSet {
            if currentTime < 0 { currentTime = 0 }
            if currentTime > totalDuration { currentTime = totalDuration }
        }
    }
    var isPlaying: Bool = false
    /// 再生倍率。1, 2, 4, 8, 16, 32, 64, 128, 256, 512
    var speed: Double = 16

    static let speedPresets: [Double] = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]

    // 内部
#if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?
#else
    private var timer: Timer?
#endif
    private var lastTickAt: CFTimeInterval = 0

    init(trackPoints: [TrackPoint]) {
        self.trackPoints = trackPoints
        self.totalDuration = trackPoints.last?.timeSec ?? 0
        // 90 秒前後で再生完了するプリセット倍速を自動選択。
        // 5K (25 分) → 16×、フル (3:30) → 128×、100K (12h) → 512× 程度。
        self.speed = PlaybackMath.defaultPlaybackSpeed(
            totalTimeSec: totalDuration,
            presets: Self.speedPresets
        )
    }

    deinit {
#if canImport(UIKit)
        displayLink?.invalidate()
#else
        timer?.invalidate()
#endif
    }

    // MARK: - Controls

    func play() {
        guard !isPlaying else { return }
        guard totalDuration > 0 else { return }
        if currentTime >= totalDuration { currentTime = 0 }  // 終了状態から押せばリスタート
        isPlaying = true
        lastTickAt = CACurrentMediaTime()

#if canImport(UIKit)
        // CADisplayLink で表示同期。ProMotion 端末では 120Hz、それ以外は 60Hz。
        // Timer ベースだと 30/60Hz でもフレーム取りこぼしでジッタが発生するが、
        // 表示同期にすれば各フレームちょうどで currentTime を更新できる。
        let proxy = DisplayLinkProxy { [weak self] in self?.tick() }
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.invoke))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.displayLinkProxy = proxy
        self.displayLink = link
#else
        // macOS は CADisplayLink(target:selector:) が unavailable。
        // 60Hz Timer フォールバック (NSView 経由の displayLink にしてもよいが、ここはコントローラ層)。
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
#endif
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
#if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
#else
        timer?.invalidate()
        timer = nil
#endif
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        currentTime = max(0, min(totalDuration, time))
    }

    func skip(by deltaSec: TimeInterval) {
        seek(to: currentTime + deltaSec)
    }

    func reset() {
        pause()
        currentTime = 0
    }

    func changeSpeed(_ newSpeed: Double) {
        speed = max(1, newSpeed)
    }

    // MARK: - Derived

    /// 現在の補間トラックポイント
    var currentPoint: TrackPoint? {
        PlaybackMath.interpolatedPoint(in: trackPoints, at: currentTime)
    }

    /// カメラの向きを決定するために少し先のポイント。
    /// `sec` を指定するとそのまま使い、省略時は倍速に応じた簡易計算をする。
    func lookAheadPoint(sec: TimeInterval? = nil) -> TrackPoint? {
        let lookSec = sec ?? max(4, min(20, speed / 4))
        return PlaybackMath.lookAheadPoint(in: trackPoints, from: currentTime, lookAheadSec: lookSec)
    }

    /// 既に走った区間のうち「最後に通過したトラックポイントまで」。
    /// 補間中の末端は含めないので、トラックポイントを跨いだ瞬間だけ配列が伸びる。
    /// 描画用 MapPolyline は本来この粒度で再構築されれば十分で、120Hz の body 再評価ごとに
    /// 2000 点の配列を毎回作り直すと MapKit が描画スキップを起こす。
    var traveledPoints: [TrackPoint] {
        guard !trackPoints.isEmpty else { return [] }
        let lo = lastReachedIndex(at: currentTime)
        return Array(trackPoints[0...lo])
    }

    /// 直近で通過したトラックポイントの index を直接公開する。
    /// MKMapView 側で「index が動いた時だけ MKPolyline を作り直す」判定に使う。
    var lastReachedIndexValue: Int {
        guard !trackPoints.isEmpty else { return 0 }
        return lastReachedIndex(at: currentTime)
    }

    /// 直近のトラックポイントから補間中の現在位置までの 2 点ペア。
    /// 走者マーカーと走破ライン本体の隙間を埋める「ヒゲ」として使う。
    /// 2 点しかないので 120Hz で毎フレーム作り直しても負荷はほぼない。
    var traveledTailSegment: [CLLocationCoordinate2D]? {
        guard !trackPoints.isEmpty else { return nil }
        guard let cur = currentPoint else { return nil }
        let lo = lastReachedIndex(at: currentTime)
        let tail = trackPoints[lo]
        // 最終点に到達後は重複するので隙間描画不要。
        if tail.timeSec == cur.timeSec { return nil }
        return [tail.coordinate, cur.coordinate]
    }

    /// `time` 以下で最後に通過したトラックポイントの index を二分探索で返す。
    private func lastReachedIndex(at time: TimeInterval) -> Int {
        var lo = 0
        var hi = trackPoints.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if trackPoints[mid].timeSec <= time { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    var progressFraction: Double {
        guard totalDuration > 0 else { return 0 }
        return currentTime / totalDuration
    }

    // MARK: - Internal

    private func tick() {
        let now = CACurrentMediaTime()
        let realDelta = now - lastTickAt
        lastTickAt = now
        currentTime += realDelta * speed
        if currentTime >= totalDuration {
            currentTime = totalDuration
            pause()
        }
    }
}

#if canImport(UIKit)
/// CADisplayLink 用の `@objc` セレクタ受け口。
/// PlaybackController 自体を NSObject 派生にすると `@Observable` との取り合いが面倒なので
/// 軽量プロキシで取り回す。link.invalidate() で link 側の retain が外れる。
private final class DisplayLinkProxy: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    @objc func invoke() { action() }
}
#endif
