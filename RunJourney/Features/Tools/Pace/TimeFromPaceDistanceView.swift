import SwiftUI

/// Time モード: ペース + 距離 → 合計タイム
struct TimeFromPaceDistanceView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var distanceKm: Double = 42.195
    @State private var distanceText: String = ""
    /// ペースは内部 sec/km で保持。ユーザーは表示単位 (sec/km or sec/mi) で操作する。
    @State private var pacePerKm: Int = 5 * 60

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var totalSec: Int {
        guard distanceKm > 0, pacePerKm > 0 else { return 0 }
        return Int((Double(pacePerKm) * distanceKm).rounded())
    }

    /// PaceTimeSpinner は秒数を Int で扱う。表示単位に応じて bind する。
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

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Distance")
                DistancePresetChips(distanceKm: $distanceKm)
                distanceField
            }

            ToolsResultCard(title: "Time") {
                Text(totalSec > 0 ? PaceUtils.formatTimeSimple(totalSec) : "—")
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .onAppear { distanceText = formatDistanceText() }
        .onChange(of: distanceKm) { _, _ in distanceText = formatDistanceText() }
        .onChange(of: distanceUnitRaw) { _, _ in distanceText = formatDistanceText() }
    }

    private var distanceField: some View {
        HStack {
#if os(iOS)
            TextField(unit.label, text: $distanceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .onSubmit { commitDistance() }
#else
            TextField(unit.label, text: $distanceText)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .onSubmit { commitDistance() }
#endif
            Text(unit.label)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatDistanceText() -> String {
        PaceUtils.formatDistanceValue(km: distanceKm, in: unit)
    }

    private func commitDistance() {
        let s = distanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(s), parsed > 0 else {
            distanceText = formatDistanceText()
            return
        }
        distanceKm = parsed.toKm(from: unit)
    }
}
