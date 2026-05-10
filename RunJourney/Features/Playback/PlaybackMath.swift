import Foundation
import CoreLocation

/// 山の高低差を擬似的に強調するカメラトリック設定。
/// Apple MapKit は地形高さの倍率 API を提供しないため、カメラの仰角を水平寄りにして
/// 距離を縮めることで、山が縦に伸びて見える効果を作る。
enum ElevationEmphasis: String, CaseIterable, Identifiable, Codable {
    case off, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:    return "Off"
        case .low:    return "Low"
        case .medium: return "Med"
        case .high:   return "High"
        }
    }
    /// プロファイルの user-angle に対する負方向シフト (度数)。下げるほど水平視点 = 山が高く見える。
    var angleDelta: Double {
        switch self {
        case .off:    return 0
        case .low:    return -5
        case .medium: return -10
        case .high:   return -15
        }
    }
    /// プロファイル distance への倍率 (短いほど迫力が出る)。
    var distanceScale: Double {
        switch self {
        case .off:    return 1.00
        case .low:    return 0.85
        case .medium: return 0.70
        case .high:   return 0.55
        }
    }

    static let userDefaultsKey = "flythrough.elevationEmphasis"
}

/// 距離プロファイルから計算したフライスルーカメラの全パラメータ。
struct FollowCameraProfile: Equatable {
    /// MapKit カメラ距離 (m)。ユーザ上書き可能。
    var distance: Double
    /// カメラ user-angle (0..180 度)。
    /// 0 = 後方地面レベル、90 = 真上俯瞰、180 = 前方地面レベル。
    /// 実 MapKit pitch への変換は `PlaybackMath.angleToMapPitch(_:)` で行う。
    var angle: Double
    /// 進行方向決定のための先読み時間 (秒)。
    var lookAheadSec: Double
    /// 中心追従の smoothDamp smoothTime (秒)。
    var centerResponseSec: Double
    /// 方位角追従の smoothDamp smoothTime (秒)。
    var bearingResponseSec: Double

    // MARK: Deadband / soft-zone (marathon-record-app port)

    /// この角度差以内ならカメラを回さない。GPS ノイズや微細なジグザグを無視する。
    var bearingDeadbandDeg: Double = 10
    /// デッドバンドを超えてこの角度差まで softBlend で徐々に追従。
    var bearingSoftZoneDeg: Double = 20
    /// この距離差以内ならカメラを動かさない (m)。
    var centerDeadbandM: Double = 10
    /// デッドバンドを超えてこの距離まで softBlend (m)。
    var centerSoftZoneM: Double = 40

    static let marathonDefault = FollowCameraProfile(
        distance: 3000,
        angle: 75,
        lookAheadSec: 4,
        centerResponseSec: 0.26,
        bearingResponseSec: 1.5
    )
}

/// プレイバック中のトラックポイント補間と方位角計算。
enum PlaybackMath {

    /// 指定時刻 `time` (秒) における仮想トラックポイントを線形補間で生成。
    /// `points` は `timeSec` 昇順前提。
    static func interpolatedPoint(in points: [TrackPoint], at time: TimeInterval) -> TrackPoint? {
        guard !points.isEmpty else { return nil }
        guard let first = points.first else { return nil }
        if time <= first.timeSec { return first }
        guard let last = points.last else { return nil }
        if time >= last.timeSec { return last }

        // 二分探索で挟む2点を見つける
        var lo = 0
        var hi = points.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if points[mid].timeSec <= time { lo = mid } else { hi = mid }
        }
        let prev = points[lo]
        let next = points[hi]
        let span = next.timeSec - prev.timeSec
        guard span > 0 else { return prev }
        let t = (time - prev.timeSec) / span

        return TrackPoint(
            timeSec: time,
            distanceM: lerp(prev.distanceM, next.distanceM, t),
            lat: lerp(prev.lat, next.lat, t),
            lng: lerp(prev.lng, next.lng, t),
            altitudeM: lerpOptional(prev.altitudeM, next.altitudeM, t),
            heartRate: t < 0.5 ? prev.heartRate : next.heartRate,  // 整数なので切替式
            speedMs: lerpOptional(prev.speedMs, next.speedMs, t),
            cadence: t < 0.5 ? prev.cadence : next.cadence,
            powerW: lerpOptional(prev.powerW, next.powerW, t),
            temperatureC: lerpOptional(prev.temperatureC, next.temperatureC, t)
        )
    }

    /// 2点間の進行方位（度数、北=0, 東=90）。地球を球とみなす近似。
    static func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLng = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let rad = atan2(y, x)
        let deg = rad * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// 現在位置から`lookAheadSec`秒先のトラックポイントを返す（カメラの向き決定に使う）。
    /// 末尾を超えたら最終点を返す。
    static func lookAheadPoint(in points: [TrackPoint], from currentTime: TimeInterval, lookAheadSec: TimeInterval = 8) -> TrackPoint? {
        let target = currentTime + lookAheadSec
        return interpolatedPoint(in: points, at: target)
    }

    /// ルートの総距離(m)に応じた推奨カメラ距離(m)。
    /// 後方互換のため残置。新しいコードは `followCameraProfile(distanceKm:)` を使うこと。
    static func recommendedCameraDistance(totalDistanceM: Double) -> Double {
        followCameraProfile(distanceKm: totalDistanceM / 1000).distance
    }

    // MARK: - Distance-based camera profile

    /// ルート長に応じてカメラ姿勢・追従応答・先読みをまとめて返す。
    /// 移植元: `marathon-record-app/src/components/map/RouteFlythru.tsx` の `getFollowCameraProfile`。
    /// - Parameter emphasis: 山の高低差を強調するカメラトリック (None/Low/Med/High)。
    ///   ユーザが Angle/Distance を手動上書きしている時はこの効果は無視される (effective* 側で trump)。
    static func followCameraProfile(distanceKm: Double, emphasis: ElevationEmphasis = .off) -> FollowCameraProfile {
        let factor = profileFactor(distanceKm: distanceKm)
        let shortBias = max(-factor, 0)
        let longBias  = max( factor, 0)

        // フルマラソン基準値: distance=3000m (2x), angle=75 (= MapKit pitch 75, 後方視点), lookAhead=4s
        let baseDistance = clamp(
            3000 - shortBias * 1400 + longBias * 1600,
            min: 1200, max: 7000
        )
        let baseAngle = clamp(
            75 + shortBias * 1.5 - longBias * 3.2,
            min: 65, max: 80
        )
        // Emphasis 適用: angle を下げて水平寄りに、distance も縮める。
        let angle = clamp(baseAngle + emphasis.angleDelta, min: 30, max: 85)
        let distance = clamp(baseDistance * emphasis.distanceScale, min: 600, max: 7000)

        let lookAhead = clamp(
            4.0 - shortBias * 0.45 + longBias * 1.0,
            min: 3.0, max: 6.5
        )
        let bearingResp = clamp(
            1.5 - shortBias * 0.32 + longBias * 0.64,
            min: 0.8, max: 3.5
        )
        let centerResp = clamp(
            0.26 - shortBias * 0.05 + longBias * 0.10,
            min: 0.17, max: 0.50
        )

        // デッドバンド: 短距離ほど小さく（GPS 精度が良い）、長距離ほど大きく（ノイズ耐性）
        let bearingDeadband = clamp(10 - shortBias * 2.5 + longBias * 3.0, min: 6, max: 15)
        let bearingSoftZone = clamp(20 - shortBias * 4.0 + longBias * 5.0, min: 12, max: 30)
        let centerDeadband = clamp(10 - shortBias * 3.0 + longBias * 7.0, min: 4, max: 24)
        let centerSoftZone = clamp(40 - shortBias * 11.0 + longBias * 35.0, min: 18, max: 110)

        return FollowCameraProfile(
            distance: distance,
            angle: angle,
            lookAheadSec: lookAhead,
            centerResponseSec: centerResp,
            bearingResponseSec: bearingResp,
            bearingDeadbandDeg: bearingDeadband,
            bearingSoftZoneDeg: bearingSoftZone,
            centerDeadbandM: centerDeadband,
            centerSoftZoneM: centerSoftZone
        )
    }

    // MARK: - Angle / Heading mapping (user-angle 0..180 -> MapKit pitch + heading flip)

    /// ユーザ角度 (0..180 度) を MapKit pitch (0..85) に変換。
    /// - 0   = カメラ後方地面 (mapPitch ~85, 水平視点)
    /// - 90  = 真上俯瞰 (mapPitch 0)
    /// - 180 = カメラ前方地面 (mapPitch ~85, ただし heading 180 度反転は呼び出し側で処理)
    static func angleToMapPitch(_ userAngle: Double) -> Double {
        let clamped = clamp(userAngle, min: 0, max: 180)
        let absDelta = abs(clamped - 90)             // 0..90
        return min(85, 90 - absDelta)                // 0..85
    }

    /// userAngle が 90 を跨いだら heading を 180 度反転して「前方から後ろを見る」状態にする。
    /// 88..92 はデッドゾーン (top-down 付近で急激な heading 反転を起こさない)。
    static func headingFlip(forAngle userAngle: Double) -> Double {
        if userAngle > 92 { return 180 }
        return 0
    }

    /// デッドバンド / ソフトゾーン のブレンド係数を返す。
    /// - delta < deadband         → 0.0 (カメラ更新しない)
    /// - delta in deadband..total → 線形 0..1
    /// - delta >= deadband+soft   → 1.0 (フル追従)
    static func softBlendFactor(delta: Double, deadband: Double, softZone: Double) -> Double {
        let absD = abs(delta)
        guard absD > deadband else { return 0 }
        let total = deadband + softZone
        guard absD < total else { return 1 }
        return (absD - deadband) / softZone
    }

    /// `target = totalTimeSec / 90` 秒 を狙ってプリセット倍速の中で最も近いものを返す。
    /// 移植元: 同じく `getDefaultSpeed`。
    static func defaultPlaybackSpeed(totalTimeSec: Double, presets: [Double]) -> Double {
        guard totalTimeSec > 0, !presets.isEmpty else { return presets.first ?? 1 }
        let target = max(totalTimeSec / 90.0, 1.0)
        return presets.reduce(presets[0]) { best, candidate in
            let bestDelta = abs(log2(best) - log2(target))
            let candDelta = abs(log2(candidate) - log2(target))
            return candDelta < bestDelta ? candidate : best
        }
    }

    private static let referenceMarathonKm: Double = 42.195
    private static let minProfileFactor: Double = -1.35
    private static let maxProfileFactor: Double =  1.45

    private static func profileFactor(distanceKm: Double) -> Double {
        guard distanceKm.isFinite, distanceKm > 0 else { return 0 }
        return clamp(log2(distanceKm / referenceMarathonKm), min: minProfileFactor, max: maxProfileFactor)
    }

    private static func clamp(_ v: Double, min lo: Double, max hi: Double) -> Double {
        Swift.min(Swift.max(v, lo), hi)
    }

    // MARK: - Lerp helpers

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func lerpOptional(_ a: Double?, _ b: Double?, _ t: Double) -> Double? {
        switch (a, b) {
        case let (a?, b?): return a + (b - a) * t
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }
}

/// 角度の差を最短回転で補間する（heading 補間用）。
/// 例: 350° から 10° は -20° の差として扱う（時計回りに20°）。
enum AngleMath {
    /// `current` から `target` へ最短経路で進む角度（度数）。
    static func shortestDelta(from current: Double, to target: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    /// 角度を最短経路で線形補間。`t` は 0..1。
    static func lerp(from current: Double, to target: Double, t: Double) -> Double {
        let delta = shortestDelta(from: current, to: target)
        return (current + delta * t).truncatingRemainder(dividingBy: 360)
    }

    /// smoothDamp 式: 慣性付きで target に近づく。フライスルーのカメラに使う。
    /// - Parameters:
    ///   - current: 現在値
    ///   - target: 目標値
    ///   - velocity: inout 速度（次の呼び出しに引き継ぐ）
    ///   - smoothTime: 0.2〜0.5 (秒)
    ///   - dt: フレーム時間 (秒)
    static func smoothDampAngle(
        from current: Double,
        to target: Double,
        velocity: inout Double,
        smoothTime: Double,
        dt: Double
    ) -> Double {
        let delta = shortestDelta(from: current, to: target)
        let resolvedTarget = current + delta
        // unity-style smoothDamp
        let omega = 2.0 / max(smoothTime, 0.0001)
        let x = omega * dt
        let exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
        let change = current - resolvedTarget
        let temp = (velocity + omega * change) * dt
        velocity = (velocity - omega * temp) * exp
        let result = resolvedTarget + (change + temp) * exp
        return result.truncatingRemainder(dividingBy: 360)
    }

    /// スカラー値版 smoothDamp。緯度・経度・距離など、角度ラップ不要な値に使う。
    static func smoothDamp(
        from current: Double,
        to target: Double,
        velocity: inout Double,
        smoothTime: Double,
        dt: Double
    ) -> Double {
        let omega = 2.0 / max(smoothTime, 0.0001)
        let x = omega * dt
        let exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
        let change = current - target
        let temp = (velocity + omega * change) * dt
        velocity = (velocity - omega * temp) * exp
        return target + (change + temp) * exp
    }
}
