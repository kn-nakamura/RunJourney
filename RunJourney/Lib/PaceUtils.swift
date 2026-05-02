import Foundation
import SwiftUI

/// Web 版 marathon-record-app の `src/lib/paceUtils.ts` を Swift 化したもの。
/// 純粋関数の集合 (副作用なし)。
enum PaceUtils {

    // MARK: - Formatters

    /// 秒 → "M:SS"
    static func formatPaceSimple(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 秒 → "H:MM:SS" (1 時間以上) もしくは "M:SS"
    static func formatTimeSimple(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// 距離ラベル (整数 km なら "5"、小数なら "21.10" 等)
    static func formatDistanceLabel(_ km: Double) -> String {
        if km == km.rounded() {
            return String(format: "%.0f", km)
        }
        return String(format: km >= 10 ? "%.1f" : "%.3f", km)
    }

    // MARK: - Calculations

    /// 目標タイム (秒) と距離 (km) からペース (秒/km) を整数で返す。
    /// 切り捨てで丸める (Web 版 paceUtils.ts:35-37 と同じ)
    static func goalTimeToPace(goalTimeSeconds: Int, distanceKm: Double) -> Int {
        guard distanceKm > 0 else { return 0 }
        return Int(floor(Double(goalTimeSeconds) / distanceKm))
    }

    /// ペース (秒/km) と距離 (km) から目標タイム (秒) を返す。
    static func paceToGoalTime(pacePerKm: Int, distanceKm: Double) -> Int {
        Int((Double(pacePerKm) * distanceKm).rounded())
    }
}

// MARK: - Lap segment

/// 1 ラップの情報。Web 版 `PaceLapSegment` 相当 (必要最小限のフィールド)。
struct PaceLapSegment: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    /// "5", "10", "HALF", "GOAL" 等
    let distanceLabel: String
    let startKm: Double
    let endKm: Double
    let segmentKm: Double
    let pacePerKm: Int
    let lapTime: Double         // セグメント所要秒
    let cumulativeTime: Double  // 累積秒
}

extension PaceUtils {

    /// 距離・目標タイム・ラップ間隔からラップ配列を生成。
    /// HALF / GOAL マークを Web 版 (paceUtils.ts:43-90) と同じ規則で付与する。
    static func generateLaps(
        config: PaceRaceConfig,
        goalTimeSeconds: Int,
        paceOverride: Int? = nil
    ) -> [PaceLapSegment] {
        let pacePerKm = paceOverride
            ?? goalTimeToPace(goalTimeSeconds: goalTimeSeconds, distanceKm: config.distanceKm)

        var laps: [PaceLapSegment] = []
        var currentKm: Double = 0
        var cumulativeTime: Double = 0
        var index = 0

        while currentKm < config.distanceKm - 0.001 {
            let remaining = config.distanceKm - currentKm
            let segmentKm = (min(config.lapIntervalKm, remaining) * 1000).rounded() / 1000
            let endKm = ((currentKm + segmentKm) * 1000).rounded() / 1000
            let lapTime = Double(pacePerKm) * segmentKm
            cumulativeTime += lapTime

            let isGoalHalf = config.key == .half && abs(endKm - config.distanceKm) < 0.01
            let isHalfMark = config.key == .full && abs(endKm - 21.0975) < 0.01
            let isFinalFull = config.key == .full && abs(endKm - config.distanceKm) < 0.01
            let isGoalGeneric = abs(endKm - config.distanceKm) < 0.01

            let distanceLabel: String
            if isGoalHalf || isFinalFull || isGoalGeneric {
                distanceLabel = "GOAL"
            } else if isHalfMark {
                distanceLabel = "HALF"
            } else {
                distanceLabel = formatDistanceLabel(endKm)
            }

            laps.append(PaceLapSegment(
                index: index,
                distanceLabel: distanceLabel,
                startKm: currentKm,
                endKm: endKm,
                segmentKm: segmentKm,
                pacePerKm: pacePerKm,
                lapTime: lapTime,
                cumulativeTime: cumulativeTime
            ))

            currentKm = endKm
            index += 1
        }

        return laps
    }

    // MARK: - Lap table helpers (PaceTable visualization)

    /// `upToIndex` 行までの累積平均ペース (秒/km)。Web 版 paceUtils.ts:112-124 と同じ。
    /// 累積走行時間 / 累積距離。距離が 0 のときは 0。
    static func getAveragePace(laps: [PaceLapSegment], upToIndex: Int) -> Int {
        guard upToIndex >= 0, upToIndex < laps.count else { return 0 }
        let slice = laps[0...upToIndex]
        let totalTime = slice.reduce(0.0) { $0 + $1.lapTime }
        let totalKm = slice.reduce(0.0) { $0 + $1.segmentKm }
        guard totalKm > 0 else { return 0 }
        return Int((totalTime / totalKm).rounded())
    }

    /// ペースバーの色。Web 版 paceUtils.ts:288-299 と同じ 3 段階分岐。
    /// `min == max` のとき (一定ペース) は teal で固定。
    static func paceBarColor(pace: Int, minPace: Int, maxPace: Int) -> Color {
        guard maxPace > minPace else { return Color(hex: 0x4ECDC4) }
        let ratio = Double(pace - minPace) / Double(maxPace - minPace)
        if ratio < 0.33 { return Color(hex: 0x00D4AA) } // emerald (fast)
        if ratio < 0.66 { return Color(hex: 0x4ECDC4) } // teal (medium)
        return Color(hex: 0xE94560)                     // red (slow)
    }

    /// バー幅 (0..1)。Web 版と同じ計算で、最小 4% を下限とする。
    static func paceBarRatio(pace: Int, minPace: Int, maxPace: Int) -> Double {
        guard maxPace > minPace else { return 0.5 }
        let lo = Double(minPace) * 0.9
        let hi = Double(maxPace) * 1.1
        let raw = (Double(pace) - lo) / (hi - lo)
        return max(0.04, min(1.0, raw))
    }
}
