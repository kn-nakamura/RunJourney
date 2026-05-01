import Foundation

/// 自己ベスト (PB) / シーズンベスト (SB) を全結果から導出する純粋関数群。
/// SwiftDataには保存せず、表示時に都度計算する（データ更新時の整合性を保つため）。
enum PBCalculator {

    // MARK: - PB

    /// カテゴリ別の自己ベスト一覧を返す。同タイ最速時は最初に登録された結果を採用。
    static func personalBests(from results: [RaceResult]) -> [RaceCategory: RaceResult] {
        let valid = results.filter { isValidForRanking($0) }
        var pbs: [RaceCategory: RaceResult] = [:]
        for r in valid {
            guard let race = r.race else { continue }
            if let existing = pbs[race.category] {
                if (r.finishTimeSec ?? .infinity) < (existing.finishTimeSec ?? .infinity) {
                    pbs[race.category] = r
                }
            } else {
                pbs[race.category] = r
            }
        }
        return pbs
    }

    /// 特定カテゴリの自己ベスト1件
    static func personalBest(category: RaceCategory, in results: [RaceResult]) -> RaceResult? {
        results
            .filter { isValidForRanking($0) && $0.race?.category == category }
            .min { ($0.finishTimeSec ?? .infinity) < ($1.finishTimeSec ?? .infinity) }
    }

    // MARK: - SB

    struct SeasonKey: Hashable {
        let category: RaceCategory
        let year: Int
    }

    /// (カテゴリ, 年) ごとのシーズンベスト一覧
    static func seasonBests(from results: [RaceResult]) -> [SeasonKey: RaceResult] {
        let valid = results.filter { isValidForRanking($0) }
        var sbs: [SeasonKey: RaceResult] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for r in valid {
            guard let race = r.race else { continue }
            let year = calendar.component(.year, from: r.raceDate)
            let key = SeasonKey(category: race.category, year: year)
            if let existing = sbs[key] {
                if (r.finishTimeSec ?? .infinity) < (existing.finishTimeSec ?? .infinity) {
                    sbs[key] = r
                }
            } else {
                sbs[key] = r
            }
        }
        return sbs
    }

    // MARK: - Aggregate stats

    struct AggregateStats {
        var totalRaces: Int = 0
        var totalDistanceM: Double = 0
        var totalTimeSec: Double = 0
        /// 全結果の重み付き平均ペース (秒/km)
        var weightedAvgPaceSecPerKm: Double? {
            guard totalDistanceM > 0 else { return nil }
            return totalTimeSec / (totalDistanceM / 1000.0)
        }
    }

    static func aggregate(from results: [RaceResult]) -> AggregateStats {
        var stats = AggregateStats()
        for r in results where isValidForRanking(r) {
            stats.totalRaces += 1
            stats.totalDistanceM += r.summary?.totalDistanceM ?? 0
            stats.totalTimeSec += r.finishTimeSec ?? 0
        }
        return stats
    }

    /// 年ごとの結果件数
    static func countsByYear(from results: [RaceResult]) -> [(year: Int, count: Int)] {
        let calendar = Calendar(identifier: .gregorian)
        var dict: [Int: Int] = [:]
        for r in results where isValidForRanking(r) {
            let y = calendar.component(.year, from: r.raceDate)
            dict[y, default: 0] += 1
        }
        return dict.sorted { $0.key < $1.key }.map { (year: $0.key, count: $0.value) }
    }

    /// カテゴリ別件数
    static func countsByCategory(from results: [RaceResult]) -> [(category: RaceCategory, count: Int)] {
        var dict: [RaceCategory: Int] = [:]
        for r in results {
            guard let cat = r.race?.category else { continue }
            dict[cat, default: 0] += 1
        }
        return RaceCategory.allCases.compactMap { cat in
            guard let count = dict[cat], count > 0 else { return nil }
            return (category: cat, count: count)
        }
    }

    // MARK: - Helpers

    private static func isValidForRanking(_ r: RaceResult) -> Bool {
        !r.isDNF && !r.isDNS && (r.finishTimeSec ?? 0) > 0
    }
}
