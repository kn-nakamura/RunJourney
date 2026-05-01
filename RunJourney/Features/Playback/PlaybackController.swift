import Foundation
import SwiftUI

/// ルートフライスルーの再生状態を管理する @Observable コントローラ。
/// CADisplayLink/Timer で `currentTime` を進める。`speed` で時間倍率を調整。
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
    private var timer: Timer?
    private var lastTickAt: Date = .now

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
        timer?.invalidate()
    }

    // MARK: - Controls

    func play() {
        guard !isPlaying else { return }
        guard totalDuration > 0 else { return }
        if currentTime >= totalDuration { currentTime = 0 }  // 終了状態から押せばリスタート
        isPlaying = true
        lastTickAt = .now
        // 30Hz: マップカメラ更新の負荷とのバランス
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        timer?.invalidate()
        timer = nil
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

    /// 既に走った区間（現在時刻まで）のトラックポイント
    var traveledPoints: [TrackPoint] {
        guard !trackPoints.isEmpty else { return [] }
        let cutoff = currentTime
        // 二分探索で「currentTime 以下」の最後のインデックスを取得
        var lo = 0
        var hi = trackPoints.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if trackPoints[mid].timeSec <= cutoff { lo = mid } else { hi = mid - 1 }
        }
        var result = Array(trackPoints[0...lo])
        if let cur = currentPoint, result.last?.timeSec != cur.timeSec {
            result.append(cur)
        }
        return result
    }

    var progressFraction: Double {
        guard totalDuration > 0 else { return 0 }
        return currentTime / totalDuration
    }

    // MARK: - Internal

    private func tick() {
        let now = Date.now
        let realDelta = now.timeIntervalSince(lastTickAt)
        lastTickAt = now
        currentTime += realDelta * speed
        if currentTime >= totalDuration {
            currentTime = totalDuration
            pause()
        }
    }
}
