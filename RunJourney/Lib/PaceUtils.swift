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

    /// Double 秒版。負値は 0 にクランプ。`formatTimeSimple(Int)` と同形式。
    static func formatDuration(_ totalSec: Double) -> String {
        formatTimeSimple(Int(max(0, totalSec).rounded()))
    }

    /// 経過時間を「日 / 時 / 分」で要約 (Dashboard の Total Time 用)。
    /// 24h 以上は "Nd Nh"、1h 以上は "Nh Nm"、それ以下は "Nm"。
    static func formatTotalTime(_ totalSec: Double) -> String {
        guard totalSec > 0 else { return "—" }
        let s = Int(totalSec)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h >= 24 {
            return "\(h / 24)d \(h % 24)h"
        }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// Double 秒/km → "M:SS" (ユニット suffix なし)。チャート軸/インライン表示向け。
    static func formatPaceShort(secPerKm: Double, in u: DistanceUnit) -> String {
        let displayed = paceSecondsPerUnit(secPerKm: Int(secPerKm.rounded()), in: u)
        return formatPaceSimple(displayed)
    }

    /// Double 秒/km → "M:SS /unit" (ユニット suffix あり)。詳細ラベル向け。
    static func formatPaceWithUnit(secPerKm: Double, in u: DistanceUnit) -> String {
        "\(formatPaceShort(secPerKm: secPerKm, in: u))\(u.perLabel)"
    }

    /// 距離ラベル (整数 km なら "5"、小数なら "21.10" 等)
    static func formatDistanceLabel(_ km: Double) -> String {
        if km == km.rounded() {
            return String(format: "%.0f", km)
        }
        return String(format: km >= 10 ? "%.1f" : "%.3f", km)
    }

    // MARK: - Unit-aware formatters (km / mi)

    /// 内部 km 値をユーザー表示単位で「値 + unit ラベル」に整形 (例: "42.195 km", "26.219 mi")
    static func formatDistance(km: Double, in u: DistanceUnit) -> String {
        return "\(formatDistanceValue(km: km, in: u)) \(u.label)"
    }

    /// 内部 km 値を表示単位の数値だけにする (suffix は呼び出し側で付ける)
    /// 整数値はそのまま、小数は3桁まで保持して末尾の 0 を削る (42.195, 21.098, 5 など)
    static func formatDistanceValue(km: Double, in u: DistanceUnit) -> String {
        return formatDistanceNumber(km.displayed(in: u))
    }

    /// 数値を「3 桁丸め + 末尾 0/. 削除」した文字列に整形。100 以上は 1 桁。
    private static func formatDistanceNumber(_ v: Double) -> String {
        if v == v.rounded() {
            return String(format: "%.0f", v)
        }
        if abs(v) >= 100 {
            return String(format: "%.1f", v)
        }
        var s = String(format: "%.3f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// ペース (秒/km) を表示単位の秒/単位に変換。mi のときは × kmPerMile。
    static func paceSecondsPerUnit(secPerKm: Int, in u: DistanceUnit) -> Int {
        u == .km ? secPerKm : Int((Double(secPerKm) * kmPerMile).rounded())
    }

    /// ペース (秒/km) を表示単位ラベル付きペース文字列にする (例: "5:00 /km", "8:03 /mi")
    static func formatPace(secPerKm: Int, in u: DistanceUnit) -> String {
        let sec = paceSecondsPerUnit(secPerKm: secPerKm, in: u)
        return "\(formatPaceSimple(sec))\(u.perLabel)"
    }

    /// 速度 (秒/km から) をユーザー単位 (km/h or mph) で返す
    static func speed(secPerKm: Int, in u: DistanceUnit) -> Double {
        guard secPerKm > 0 else { return 0 }
        let kmh = 3600.0 / Double(secPerKm)
        return u == .km ? kmh : kmh / kmPerMile
    }

    /// 400 m トラックの 1 周タイム (秒)。km/mi に依存しない (トラックは世界共通 400m)
    static func lapTime400m(secPerKm: Int) -> Double {
        Double(secPerKm) * 0.4
    }

    /// `M'SS"FF` 形式 (FF は秒の小数点以下 2 桁を 100 倍したもの)。Pace/Speed 結果カード用。
    static func formatPaceTrackHundredths(_ secs: Double) -> String {
        let total = max(0, secs)
        let m = Int(total) / 60
        let s = Int(total) % 60
        let hundredths = Int((total - floor(total)) * 100)
        return String(format: "%d'%02d\"%02d", m, s, hundredths)
    }

    /// Double 秒 (秒/km) をユーザー単位に変換した秒数を返す。
    /// 例: 256.07 (sec/km) を mi で → 256.07 * 1.609344 = 412.00... (sec/mi)
    static func paceSecondsPerUnitPrecise(secPerKm: Double, in u: DistanceUnit) -> Double {
        u == .km ? secPerKm : secPerKm * kmPerMile
    }

    /// Double 秒/km からユーザー単位の `M'SS"FF /unit` 文字列にする。
    static func formatPaceHundredths(secPerKm: Double, in u: DistanceUnit) -> String {
        let secPerUnit = paceSecondsPerUnitPrecise(secPerKm: secPerKm, in: u)
        return "\(formatPaceTrackHundredths(secPerUnit))\(u.perLabel)"
    }

    /// 0:00'00" 形式 (Cheer Point の表示用 — 時:分'秒")
    static func formatHMSPaceStyle(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return String(format: "%d:%02d'%02d\"", h, m, sec)
    }

    /// 符号付き秒差を `+M:SS` / `-M:SS` 形式で返す (Plan vs Actual 用)。
    /// abs(秒) が 60 以上のときは分:秒、未満のときは秒のみ。
    static func formatSignedDuration(_ sec: Double) -> String {
        let sign = sec < 0 ? "-" : "+"
        let abs = Swift.abs(sec)
        let totalSeconds = Int(abs.rounded())
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if m > 0 {
            return String(format: "%@%d:%02d", sign, m, s)
        }
        return String(format: "%@0:%02d", sign, s)
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
    /// `perLapOverrides` を渡すと該当 index のラップだけそのペースを使う。
    static func generateLaps(
        config: PaceRaceConfig,
        goalTimeSeconds: Int,
        paceOverride: Int? = nil,
        perLapOverrides: [Int: Int] = [:]
    ) -> [PaceLapSegment] {
        let basePace = paceOverride
            ?? goalTimeToPace(goalTimeSeconds: goalTimeSeconds, distanceKm: config.distanceKm)

        var laps: [PaceLapSegment] = []
        var currentKm: Double = 0
        var cumulativeTime: Double = 0
        var index = 0

        while currentKm < config.distanceKm - 0.001 {
            let remaining = config.distanceKm - currentKm
            let segmentKm = (min(config.lapIntervalKm, remaining) * 1000).rounded() / 1000
            let endKm = ((currentKm + segmentKm) * 1000).rounded() / 1000
            let pacePerKm = perLapOverrides[index] ?? basePace
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

    /// ペースバーの色。基準ペースを中央 (amber) に置き、faster → emerald, slower → red へ補間。
    /// 0 で emerald、basePace で amber、basePace*2 以上で red に達する。
    static func paceBarColor(pace: Int, basePace: Int) -> Color {
        let mid: (Double, Double, Double)  = (0xF2 / 255, 0xC7 / 255, 0x44 / 255)
        guard basePace > 0 else { return Color(red: mid.0, green: mid.1, blue: mid.2) }
        let fast: (Double, Double, Double) = (0x00 / 255, 0xD4 / 255, 0xAA / 255)
        let slow: (Double, Double, Double) = (0xE9 / 255, 0x45 / 255, 0x60 / 255)
        let (a, b, t): ((Double, Double, Double), (Double, Double, Double), Double)
        if pace <= basePace {
            let r = max(0.0, min(1.0, Double(pace) / Double(basePace)))
            (a, b, t) = (fast, mid, r)
        } else {
            let r = max(0.0, min(1.0, Double(pace - basePace) / Double(basePace)))
            (a, b, t) = (mid, slow, r)
        }
        return Color(
            red:   a.0 + (b.0 - a.0) * t,
            green: a.1 + (b.1 - a.1) * t,
            blue:  a.2 + (b.2 - a.2) * t
        )
    }

    /// バー幅 (0..1)。`basePace` で 0.5、`basePace * 2` で 1.0 を返す。
    /// 例: basePace = 5:00 のとき pace = 10:00 で右端、5:00 でちょうど半分。
    static func paceBarRatio(pace: Int, basePace: Int) -> Double {
        guard basePace > 0 else { return 0 }
        let denom = Double(basePace) * 2.0
        return max(0.0, min(1.0, Double(pace) / denom))
    }
}
