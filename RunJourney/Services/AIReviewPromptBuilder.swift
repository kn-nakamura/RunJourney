import Foundation

/// Foundation Models 用のプロンプト生成。
/// 純粋関数のみで構成し、ユニットテストは Apple Intelligence 非依存。
/// nil フィールドは行ごと省略する（モデルに "nil" を見せない）。
enum AIReviewPromptBuilder {

    /// モデルへのシステム指示。UI 文言ではないので localize しない。
    static let systemPrompt = """
    You are an experienced running coach. Based on the provided race data, \
    write a 200–400 word reflection on the runner's performance in English. \
    Be warm, specific, and constructive — comment on pacing strategy, heart \
    rate effort, weather impact, and one or two improvement points. Do not \
    invent data not provided.
    """

    /// `RaceResult` を「Label: value」形式の英文ブロックにする。
    /// `unit` でユーザー設定 (km/mi) に追従する。
    static func buildUserPrompt(
        result: RaceResult,
        race: Race?,
        plan: PacePlan?,
        unit: DistanceUnit
    ) -> String {
        var lines: [String] = []

        if let race {
            lines.append("Race: \(race.name)")
            lines.append("Category: \(race.category.displayName)")
        }

        lines.append("Date: \(Self.dateFormatter.string(from: result.raceDate))")

        if result.isDNF {
            lines.append("Status: DNF (did not finish)")
        } else if result.isDNS {
            lines.append("Status: DNS (did not start)")
        }
        if result.isPB { lines.append("Personal Best: yes") }
        if result.isSB { lines.append("Season Best: yes") }

        if let totalM = result.summary?.totalDistanceM, totalM > 0 {
            lines.append("Distance: \(PaceUtils.formatDistance(km: totalM / 1000, in: unit))")
        } else if let km = race?.distanceKm {
            lines.append("Distance: \(PaceUtils.formatDistance(km: km, in: unit))")
        }

        if let sec = result.finishTimeSec, sec > 0 {
            lines.append("Finish Time: \(PaceUtils.formatDuration(sec))")
        }

        if let pace = result.summary?.avgPaceSecPerKm, pace > 0 {
            lines.append("Avg Pace: \(PaceUtils.formatPaceWithUnit(secPerKm: pace, in: unit))")
        }

        if let hr = result.summary?.avgHeartRate { lines.append("Avg HR: \(hr) bpm") }
        if let hr = result.summary?.maxHeartRate { lines.append("Max HR: \(hr) bpm") }
        if let g = result.summary?.elevationGainM { lines.append("Elevation Gain: \(Int(g.rounded())) m") }
        if let l = result.summary?.elevationLossM { lines.append("Elevation Loss: \(Int(l.rounded())) m") }
        if let c = result.summary?.avgCadence { lines.append("Avg Cadence: \(c) spm") }
        if let p = result.summary?.avgPowerW { lines.append("Avg Power: \(Int(p.rounded())) W") }
        if let cal = result.summary?.totalCalories { lines.append("Calories: \(Int(cal.rounded())) kcal") }
        if let temp = result.summary?.avgTemperatureC {
            lines.append("Avg Temperature: \(String(format: "%.1f", temp)) °C")
        }

        if let w = result.weatherDescription { lines.append("Weather: \(w.displayName)") }
        if let t = result.weatherTempC {
            lines.append("Weather Temperature: \(String(format: "%.1f", t)) °C")
        }
        if let cond = result.condition { lines.append("Self-rated Condition: \(cond.displayName)") }

        if let place = result.overallPlace {
            if let total = result.totalFinishers {
                lines.append("Placement: \(place) / \(total)")
            } else {
                lines.append("Placement: \(place)")
            }
        }
        if let agp = result.ageGroupPlace { lines.append("Age Group Place: \(agp)") }

        if let split = AdvancedAnalytics.halfSplit(result.trackPoints) {
            let delta = split.secondHalfSec - split.firstHalfSec
            let label = delta < 0 ? "negative split" : (delta > 0 ? "positive split" : "even split")
            lines.append("Half Split: 1st \(PaceUtils.formatDuration(split.firstHalfSec)) / 2nd \(PaceUtils.formatDuration(split.secondHalfSec)) (\(label), Δ \(PaceUtils.formatSignedDuration(delta)))")
        }

        if let plan {
            let target = PaceUtils.formatPaceWithUnit(secPerKm: plan.paceSecPerKm, in: unit)
            let planLabel = plan.name.isEmpty ? "linked plan" : plan.name
            lines.append("Plan: \(planLabel) — target pace \(target)")
            let deltas = AdvancedAnalytics.planLapDeltas(actual: result.lapData, targetSecPerKm: plan.paceSecPerKm)
            if let last = deltas.last {
                lines.append("Plan Delta (cumulative): \(PaceUtils.formatSignedDuration(last.cumulativeSec))")
            }
        }

        if !result.lapData.isEmpty {
            lines.append("Lap Count: \(result.lapData.count)")
            lines.append("")
            lines.append("Splits (lap: distance · time · pace · HR):")
            for line in formatLapLines(result.lapData, unit: unit) {
                lines.append(line)
            }
        }

        if let comment = result.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
            lines.append("")
            lines.append("User Note: \(comment)")
        }

        lines.append("")
        lines.append("Write the reflection now.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// 多すぎるラップは前3 + 中略 + 後3 に圧縮 (token 節約)。
    private static func formatLapLines(_ laps: [LapData], unit: DistanceUnit) -> [String] {
        let formatted: [(Int, String)] = laps.map { lap in
            let dist = PaceUtils.formatDistance(km: lap.distanceM / 1000, in: unit)
            let time = PaceUtils.formatDuration(lap.timeSec)
            let pace = PaceUtils.formatPaceWithUnit(secPerKm: lap.paceSecPerKm, in: unit)
            let hrText = lap.avgHeartRate.map { "HR \($0)" } ?? "HR —"
            return (lap.lapIndex, "  \(lap.lapIndex). \(dist) · \(time) · \(pace) · \(hrText)")
        }
        if formatted.count <= 6 {
            return formatted.map(\.1)
        }
        let head = formatted.prefix(3).map(\.1)
        let tail = formatted.suffix(3).map(\.1)
        let omitted = formatted.count - 6
        return head + ["  … (\(omitted) laps omitted) …"] + tail
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
