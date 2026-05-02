import SwiftUI

/// Distance モード: ペース + 時間 → 距離
struct DistanceFromPaceTimeView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var pacePerKm: Int = 5 * 60
    @State private var timeSec: Int = 3600

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var distanceKm: Double {
        guard pacePerKm > 0 else { return 0 }
        return Double(timeSec) / Double(pacePerKm)
    }

    private var displayedPaceBinding: Binding<Int> {
        Binding(
            get: { PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit) },
            set: { displayed in
                pacePerKm = unit == .km ? displayed : Int((Double(displayed) / kmPerMile).rounded())
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaceTimeSpinner(
                title: "Pace \(unit.perLabel)",
                mode: .pace,
                seconds: displayedPaceBinding,
                derivedGoalTimeSeconds: nil
            )

            PaceTimeSpinner(
                title: "Time",
                mode: .goalTime,
                seconds: $timeSec,
                derivedGoalTimeSeconds: nil
            )

            ToolsResultCard(title: "Distance") {
                Text(distanceKm > 0 ? PaceUtils.formatDistance(km: distanceKm, in: unit) : "—")
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
            }
        }
    }
}
