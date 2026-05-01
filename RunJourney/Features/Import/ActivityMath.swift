import Foundation
import CoreLocation

/// アクティビティ解析の数値計算ユーティリティ。
enum ActivityMath {

    /// 2点間の球面距離（メートル）。Web版 haversineMeters と同等。
    static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    /// ISO 8601 / RFC 3339 文字列を `Date` に変換。秒の小数あり/なし両対応。
    static func parseISODate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = isoFractionalFormatter.date(from: trimmed) { return date }
        if let date = isoBasicFormatter.date(from: trimmed) { return date }
        return nil
    }

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasicFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// プレイバック用にトラックポイントを間引く。
    /// 4時間マラソン1Hzで14400点 → 滑らかなアニメに必要なのは ~180 点。
    /// 6時間以上のアクティビティは少し増やす。
    static func sampleTrackPoints(_ points: [TrackPoint], targetCount: Int? = nil) -> [TrackPoint] {
        guard points.count > 0 else { return [] }
        let totalSeconds = points.last?.timeSec ?? 0
        let target = targetCount ?? (totalSeconds > 6 * 3600 ? 360 : 180)
        guard points.count > target else { return points }

        var result: [TrackPoint] = []
        result.reserveCapacity(target)
        for i in 0..<target {
            let idx = Int(Double(i) * Double(points.count - 1) / Double(target - 1))
            result.append(points[idx])
        }
        // 最終点は必ず含める
        if result.last?.id != points.last?.id {
            result.append(points.last!)
        }
        return result
    }

    /// 時系列ポイントとラップから全体集計を組み立てる。
    static func buildSummaryStats(trackPoints: [TrackPoint], laps: [LapData]) -> SummaryStats {
        var summary = SummaryStats()

        if let last = trackPoints.last {
            summary.totalDistanceM = last.distanceM
            summary.totalTimeSec = last.timeSec
        }

        let validHRs = trackPoints.compactMap { $0.heartRate }.filter { $0 > 0 }
        if !validHRs.isEmpty {
            summary.avgHeartRate = Int(Double(validHRs.reduce(0, +)) / Double(validHRs.count))
            summary.maxHeartRate = validHRs.max()
        }

        let validCadences = trackPoints.compactMap { $0.cadence }.filter { $0 > 0 }
        if !validCadences.isEmpty {
            summary.avgCadence = Int(Double(validCadences.reduce(0, +)) / Double(validCadences.count))
            summary.maxCadence = validCadences.max()
        }

        let validPowers = trackPoints.compactMap { $0.powerW }.filter { $0 > 0 }
        if !validPowers.isEmpty {
            summary.avgPowerW = validPowers.reduce(0, +) / Double(validPowers.count)
            summary.maxPowerW = validPowers.max()
        }

        let altitudes = trackPoints.compactMap { $0.altitudeM }
        if !altitudes.isEmpty {
            summary.minAltitudeM = altitudes.min()
            summary.maxAltitudeM = altitudes.max()

            // 標高ゲイン/ロスはノイズ除去のため隣接点の差分を集計
            var gain = 0.0, loss = 0.0
            for i in 1..<altitudes.count {
                let diff = altitudes[i] - altitudes[i - 1]
                if diff > 0 { gain += diff } else { loss += -diff }
            }
            summary.elevationGainM = gain
            summary.elevationLossM = loss
        }

        let temps = trackPoints.compactMap { $0.temperatureC }
        if !temps.isEmpty {
            summary.avgTemperatureC = temps.reduce(0, +) / Double(temps.count)
        }

        // 平均ペース: 総距離・総時間から再計算（ラップ平均より正確）
        if let dist = summary.totalDistanceM, let time = summary.totalTimeSec, dist > 0 {
            summary.avgPaceSecPerKm = time / (dist / 1000.0)
        } else if !laps.isEmpty {
            let validPaces = laps.compactMap { $0.paceSecPerKm > 0 ? $0.paceSecPerKm : nil }
            if !validPaces.isEmpty {
                summary.avgPaceSecPerKm = validPaces.reduce(0, +) / Double(validPaces.count)
            }
        }

        // カロリー: ラップ合計
        let calories = laps.compactMap { $0.calories }
        if !calories.isEmpty {
            summary.totalCalories = calories.reduce(0, +)
        }

        return summary
    }
}
