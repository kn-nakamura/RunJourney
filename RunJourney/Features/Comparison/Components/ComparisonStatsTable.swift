import SwiftUI

/// レースを行に並べ、Distance/Time/Pace/HR/Cadence/Power/Ascent を列にした比較表。
/// 列毎に最良値を accentPrimary でハイライトする。
struct ComparisonStatsTable: View {
    let results: [RaceResult]
    let palette: [Color]

    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var rows: [Row] {
        results.enumerated().map { idx, r in
            Row(
                color: palette[idx % palette.count],
                date: r.raceDate,
                name: r.race?.name ?? "—",
                distanceM: r.summary?.totalDistanceM ?? 0,
                timeSec: r.finishTimeSec ?? 0,
                paceSecPerKm: r.summary?.avgPaceSecPerKm,
                avgHR: r.summary?.avgHeartRate,
                avgCadence: r.summary?.avgCadence,
                avgPowerW: r.summary?.avgPowerW,
                ascentM: r.summary?.elevationGainM
            )
        }
    }

    private struct Row {
        let color: Color
        let date: Date
        let name: String
        let distanceM: Double
        let timeSec: Double
        let paceSecPerKm: Double?
        let avgHR: Int?
        let avgCadence: Int?
        let avgPowerW: Double?
        let ascentM: Double?
    }

    /// 列ごとの最良値 (時間・ペースは最小、その他は最大)。
    private var best: (time: Double?, pace: Double?, hr: Int?, cad: Int?, pow: Double?, asc: Double?) {
        let times = rows.map(\.timeSec).filter { $0 > 0 }
        let paces = rows.compactMap(\.paceSecPerKm).filter { $0 > 0 }
        let hrs = rows.compactMap(\.avgHR).filter { $0 > 0 }
        let cads = rows.compactMap(\.avgCadence).filter { $0 > 0 }
        let pows = rows.compactMap(\.avgPowerW).filter { $0 > 0 }
        let ascs = rows.compactMap(\.ascentM).filter { $0 > 0 }
        return (
            time: times.min(),
            pace: paces.min(),
            hr: hrs.max(),
            cad: cads.max(),
            pow: pows.max(),
            asc: ascs.max()
        )
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                self.row(row)
                if idx < rows.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ r: Row) -> some View {
        let timeBest = isBestTime(r.timeSec)
        let paceBest = isBestPace(r.paceSecPerKm)
        let hrBest = isBestHR(r.avgHR)
        let cadBest = isBestCadence(r.avgCadence)
        let powBest = isBestPower(r.avgPowerW)
        let ascBest = isBestAscent(r.ascentM)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(r.color).frame(width: 8, height: 8)
                Text(r.name)
                    .appText(.bodySmBold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                    .appText(.bodyXs)
                    .foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                cell(label: "Distance", value: distanceText(r.distanceM), highlighted: false)
                cell(label: "Time", value: r.timeSec > 0 ? PaceUtils.formatDuration(r.timeSec) : "—", highlighted: timeBest)
                cell(label: "Avg Pace", value: paceText(r.paceSecPerKm), highlighted: paceBest)
                cell(label: "Avg HR", value: r.avgHR.map { "\($0) bpm" } ?? "—", highlighted: hrBest)
                cell(label: "Avg Cad", value: r.avgCadence.map { "\($0) spm" } ?? "—", highlighted: cadBest)
                cell(label: "Avg Pow", value: r.avgPowerW.map { String(format: "%.0f W", $0) } ?? "—", highlighted: powBest)
                cell(label: "Ascent", value: r.ascentM.map { String(format: "%.0f m", $0) } ?? "—", highlighted: ascBest)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func isBestTime(_ v: Double) -> Bool {
        guard v > 0, let b = best.time else { return false }
        return v == b
    }
    private func isBestPace(_ v: Double?) -> Bool {
        guard let v, v > 0, let b = best.pace else { return false }
        return v == b
    }
    private func isBestHR(_ v: Int?) -> Bool {
        guard let v, let b = best.hr else { return false }
        return v == b
    }
    private func isBestCadence(_ v: Int?) -> Bool {
        guard let v, let b = best.cad else { return false }
        return v == b
    }
    private func isBestPower(_ v: Double?) -> Bool {
        guard let v, let b = best.pow else { return false }
        return v == b
    }
    private func isBestAscent(_ v: Double?) -> Bool {
        guard let v, let b = best.asc else { return false }
        return v == b
    }

    private func cell(label: String, value: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
            Text(value)
                .appText(.codeBaseBold)
                .foregroundStyle(highlighted ? Color.accentPrimary : Color.textPrimary)
        }
    }

    private func distanceText(_ m: Double) -> String {
        guard m > 0 else { return "—" }
        return PaceUtils.formatDistance(km: m / 1000, in: unit)
    }

    private func paceText(_ secPerKm: Double?) -> String {
        guard let p = secPerKm, p > 0 else { return "—" }
        return PaceUtils.formatPace(secPerKm: Int(p.rounded()), in: unit)
    }

}
