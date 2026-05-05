import Foundation

/// `PBCalculator` の姉妹サービス。Dashboard / 個別レース詳細のリッチな指標を表示時に算出する。
/// SwiftData には永続化せず、結果データから都度導出することで整合性を最優先する。
enum AdvancedAnalytics {

    // MARK: - Helpers

    private static let calendar = Calendar(identifier: .gregorian)

    /// `nonisolated` にしている理由: ビルド設定が `-default-isolation=MainActor` のため
    /// この helper を `Array.filter(_:)` に渡すと MainActor からの脱出について警告が出る。
    /// この関数は純粋に値を読むだけなので nonisolated で問題ない。
    nonisolated private static func isValid(_ r: RaceResult) -> Bool {
        !r.isDNF && !r.isDNS && (r.finishTimeSec ?? 0) > 0
    }

    // MARK: - Activity (All モード Dashboard)

    /// 連続して年に1回以上レースを走っている年数。すべての年を一旦集合化し、
    /// 連続した区間の最大長を返す。例: [2018,2019,2020,2022,2023] → 3。
    static func longestRacingStreak(_ results: [RaceResult]) -> Int {
        let years = Set(results.filter(isValid).map { calendar.component(.year, from: $0.raceDate) })
        guard !years.isEmpty else { return 0 }
        let sorted = years.sorted()
        var best = 1, current = 1
        for i in 1..<sorted.count {
            if sorted[i] == sorted[i - 1] + 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// 一番レース数が多い年。同数なら直近年。
    static func mostActiveYear(_ results: [RaceResult]) -> (year: Int, count: Int)? {
        var dict: [Int: Int] = [:]
        for r in results where isValid(r) {
            let y = calendar.component(.year, from: r.raceDate)
            dict[y, default: 0] += 1
        }
        guard let best = dict.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key < rhs.key
        }) else { return nil }
        return (year: best.key, count: best.value)
    }

    /// 走った大会の異なり数 (Race.id でユニーク)。
    static func uniqueRaceCount(_ results: [RaceResult]) -> Int {
        Set(results.compactMap { $0.race?.id }).count
    }

    /// 走った国の異なり数 (Race.country でユニーク、空白除去)。
    static func countryCount(_ results: [RaceResult]) -> Int {
        let countries = results
            .compactMap { $0.race?.country.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(countries).count
    }

    // MARK: - Distribution

    /// 年×カテゴリの距離 (km) 集計。
    struct YearDistance: Identifiable {
        let year: Int
        let category: RaceCategory
        let distanceKm: Double
        var id: String { "\(year)-\(category.rawValue)" }
    }

    static func distancePerYear(_ results: [RaceResult]) -> [YearDistance] {
        var dict: [Int: [RaceCategory: Double]] = [:]
        for r in results where isValid(r) {
            guard let cat = r.race?.category else { continue }
            let y = calendar.component(.year, from: r.raceDate)
            let km = (r.summary?.totalDistanceM ?? 0) / 1000.0
            dict[y, default: [:]][cat, default: 0] += km
        }
        var out: [YearDistance] = []
        for (year, byCat) in dict.sorted(by: { $0.key < $1.key }) {
            for cat in RaceCategory.allCases where (byCat[cat] ?? 0) > 0 {
                out.append(YearDistance(year: year, category: cat, distanceKm: byCat[cat] ?? 0))
            }
        }
        return out
    }

    /// 月 (1〜12) ごとのレース数。空きキーは作らない。
    static func monthHeatmap(_ results: [RaceResult]) -> [Int: Int] {
        var dict: [Int: Int] = [:]
        for r in results where isValid(r) {
            let m = calendar.component(.month, from: r.raceDate)
            dict[m, default: 0] += 1
        }
        return dict
    }

    /// ペース分布。`bucketSec` 秒幅で平均ペースをヒストグラム化する。
    /// カテゴリ選択時の利用を想定 (距離が揃っていることが前提)。
    static func paceHistogram(_ results: [RaceResult], bucketSec: Int = 15) -> [(bucketStart: Int, count: Int)] {
        guard bucketSec > 0 else { return [] }
        var dict: [Int: Int] = [:]
        for r in results where isValid(r) {
            guard let pace = r.summary?.avgPaceSecPerKm, pace > 0 else { continue }
            let bucket = (Int(pace) / bucketSec) * bucketSec
            dict[bucket, default: 0] += 1
        }
        return dict.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    // MARK: - PB progression

    struct PBPoint: Identifiable {
        let date: Date
        let finishSec: Double
        var id: Date { date }
    }

    /// カテゴリ別 PB 推移。日付昇順で走り、PB を更新した結果だけを残す。
    static func pbProgression(_ results: [RaceResult]) -> [RaceCategory: [PBPoint]] {
        var dict: [RaceCategory: [PBPoint]] = [:]
        let sorted = results.filter(isValid).sorted { $0.raceDate < $1.raceDate }
        for r in sorted {
            guard let cat = r.race?.category, let sec = r.finishTimeSec else { continue }
            let arr = dict[cat] ?? []
            if let last = arr.last, sec >= last.finishSec { continue }
            dict[cat, default: []].append(PBPoint(date: r.raceDate, finishSec: sec))
        }
        return dict
    }

    /// カテゴリ単独の finish time 推移 (PB に限らず全結果)。
    static func finishTimeTimeline(_ results: [RaceResult]) -> [PBPoint] {
        results.filter(isValid)
            .sorted { $0.raceDate < $1.raceDate }
            .compactMap { r in
                guard let sec = r.finishTimeSec else { return nil }
                return PBPoint(date: r.raceDate, finishSec: sec)
            }
    }

    // MARK: - Per-race time series

    struct RollingPacePoint: Identifiable {
        let km: Double
        let paceSecPerKm: Double
        var id: Double { km }
    }

    /// 1km ごとのペース。各 km マークでの累積距離・累積時間から線形補間する。
    /// trackPoints が距離昇順で並んでいることが前提。
    static func rollingKmPace(_ points: [TrackPoint]) -> [RollingPacePoint] {
        guard points.count >= 2 else { return [] }
        let sorted = points.sorted { $0.distanceM < $1.distanceM }
        let totalKm = (sorted.last?.distanceM ?? 0) / 1000.0
        guard totalKm >= 1 else { return [] }

        var out: [RollingPacePoint] = []
        var prevTime: Double = 0
        var prevKm: Double = 0
        var idx = 0

        for kmMark in 1...Int(totalKm) {
            let targetM = Double(kmMark) * 1000.0
            while idx < sorted.count - 1 && sorted[idx + 1].distanceM < targetM {
                idx += 1
            }
            // 線形補間で targetM での時刻を求める
            let a = sorted[idx]
            let b = sorted[min(idx + 1, sorted.count - 1)]
            let t: Double = {
                let span = b.distanceM - a.distanceM
                if span <= 0 { return a.timeSec }
                let ratio = max(0, min(1, (targetM - a.distanceM) / span))
                return a.timeSec + (b.timeSec - a.timeSec) * ratio
            }()
            let segSec = t - prevTime
            let segKm = Double(kmMark) - prevKm
            let pace = segKm > 0 ? segSec / segKm : 0
            if pace > 0 {
                out.append(RollingPacePoint(km: Double(kmMark), paceSecPerKm: pace))
            }
            prevTime = t
            prevKm = Double(kmMark)
        }
        return out
    }

    /// 前半 / 後半時間 (= 総距離の 50% を超えた最初の trackPoint で分割)。
    static func halfSplit(_ points: [TrackPoint]) -> (firstHalfSec: Double, secondHalfSec: Double)? {
        guard let last = points.last, last.distanceM > 0 else { return nil }
        let half = last.distanceM / 2
        guard let mid = points.first(where: { $0.distanceM >= half }) else { return nil }
        let first = mid.timeSec
        let second = last.timeSec - mid.timeSec
        guard first > 0, second > 0 else { return nil }
        return (first, second)
    }

    // MARK: - HR zones

    enum HRZone: Int, CaseIterable, Identifiable {
        case z1 = 1, z2, z3, z4, z5
        var id: Int { rawValue }
        /// %max HR 下限 (含む)
        var lowerPct: Double {
            switch self {
            case .z1: return 0.50
            case .z2: return 0.60
            case .z3: return 0.70
            case .z4: return 0.80
            case .z5: return 0.90
            }
        }
        /// %max HR 上限 (この値未満)。Z5 のみ 1.0 をそのまま含む。
        var upperPct: Double {
            switch self {
            case .z1: return 0.60
            case .z2: return 0.70
            case .z3: return 0.80
            case .z4: return 0.90
            case .z5: return 1.01
            }
        }
        var label: String {
            switch self {
            case .z1: return "Z1"
            case .z2: return "Z2"
            case .z3: return "Z3"
            case .z4: return "Z4"
            case .z5: return "Z5"
            }
        }
        var description: String {
            switch self {
            case .z1: return "Recovery"
            case .z2: return "Endurance"
            case .z3: return "Tempo"
            case .z4: return "Threshold"
            case .z5: return "VO2 Max"
            }
        }
    }

    /// 各ゾーンに費やした秒数を返す。隣接 trackPoint の時間差を割り当てる。
    static func hrZoneDistribution(_ points: [TrackPoint], maxHR: Int) -> [HRZone: Double] {
        guard maxHR > 0, points.count >= 2 else { return [:] }
        var dict: [HRZone: Double] = [:]
        for i in 1..<points.count {
            guard let hr = points[i].heartRate, hr > 0 else { continue }
            let dt = points[i].timeSec - points[i - 1].timeSec
            guard dt > 0, dt < 600 else { continue }  // 10 分超のジャンプはスキップ
            let pct = Double(hr) / Double(maxHR)
            let zone = HRZone.allCases.first(where: { pct >= $0.lowerPct && pct < $0.upperPct }) ?? .z5
            dict[zone, default: 0] += dt
        }
        return dict
    }

    // MARK: - Pace zones

    enum PaceBucket: String, CaseIterable, Identifiable {
        case fast, target, slow
        var id: String { rawValue }
        var label: String {
            switch self {
            case .fast: return "Fast"
            case .target: return "Target"
            case .slow: return "Slow"
            }
        }
    }

    /// ラップを target ± toleranceSec 秒 (秒/km) でバケット分けし、各バケットの所要時間 (秒) を返す。
    static func paceZoneDistribution(
        laps: [LapData],
        targetSecPerKm: Double,
        toleranceSec: Int = 10
    ) -> [PaceBucket: Double] {
        guard targetSecPerKm > 0 else { return [:] }
        let tol = Double(toleranceSec)
        var dict: [PaceBucket: Double] = [:]
        for lap in laps where lap.paceSecPerKm > 0 && lap.timeSec > 0 {
            let bucket: PaceBucket
            if lap.paceSecPerKm < targetSecPerKm - tol {
                bucket = .fast
            } else if lap.paceSecPerKm > targetSecPerKm + tol {
                bucket = .slow
            } else {
                bucket = .target
            }
            dict[bucket, default: 0] += lap.timeSec
        }
        return dict
    }

    // MARK: - Grade-Adjusted Pace

    struct GAPPoint: Identifiable {
        let timeSec: Double
        let paceSecPerKm: Double
        let gapSecPerKm: Double
        var id: Double { timeSec }
    }

    /// Minetti 風 (近似) の勾配補正ペース。
    /// Δ標高 / Δ距離 を勾配 (g) として、cost(g) = 1 + 12g + 60g^2 (登り) / 1 + 6g + 30g^2 (下り) の比率を平地ペースに掛ける。
    /// 1km ごとの ローリングペースに対して適用するので、まず `rollingKmPace` 相当を時系列に展開する。
    static func gradeAdjustedPace(_ points: [TrackPoint], windowM: Double = 200) -> [GAPPoint] {
        let sorted = points.filter { $0.distanceM > 0 }.sorted { $0.distanceM < $1.distanceM }
        guard sorted.count >= 2 else { return [] }

        var out: [GAPPoint] = []
        var prevIdx = 0
        for i in 1..<sorted.count {
            let cur = sorted[i]
            // window: cur.distanceM から後ろに windowM 戻った点
            while prevIdx < i - 1 && cur.distanceM - sorted[prevIdx].distanceM > windowM {
                prevIdx += 1
            }
            let prev = sorted[prevIdx]
            let dDist = cur.distanceM - prev.distanceM
            let dTime = cur.timeSec - prev.timeSec
            guard dDist >= 50, dTime > 0 else { continue }
            let pace = dTime / (dDist / 1000.0)
            let dAlt = (cur.altitudeM ?? 0) - (prev.altitudeM ?? 0)
            let grade = dAlt / dDist
            let gradeFactor: Double
            if grade > 0 {
                gradeFactor = 1.0 + 12.0 * grade + 60.0 * grade * grade
            } else {
                let g = -grade
                let down = 1.0 - 6.0 * g - 30.0 * g * g
                gradeFactor = max(0.5, down)  // 下りは過剰補正にならないようクランプ
            }
            let gap = pace / max(0.5, gradeFactor)
            out.append(GAPPoint(timeSec: cur.timeSec, paceSecPerKm: pace, gapSecPerKm: gap))
        }
        return out
    }

    // MARK: - Plan vs Actual

    struct PlanLapDelta: Identifiable {
        let lapIndex: Int
        let actualSec: Double
        let targetSec: Double
        let deltaSec: Double
        let cumulativeSec: Double
        var id: Int { lapIndex }
    }

    /// 各ラップの target vs actual と累積差。
    /// `targetSecPerKm` が plan の平均ペースを表すので、各ラップ距離 × pace で target 秒数を作る。
    static func planLapDeltas(actual: [LapData], targetSecPerKm: Double) -> [PlanLapDelta] {
        guard targetSecPerKm > 0 else { return [] }
        var cumulative: Double = 0
        var out: [PlanLapDelta] = []
        for lap in actual where lap.distanceM > 0 && lap.timeSec > 0 {
            let target = (lap.distanceM / 1000.0) * targetSecPerKm
            let delta = lap.timeSec - target
            cumulative += delta
            out.append(PlanLapDelta(
                lapIndex: lap.lapIndex,
                actualSec: lap.timeSec,
                targetSec: target,
                deltaSec: delta,
                cumulativeSec: cumulative
            ))
        }
        return out
    }
}
