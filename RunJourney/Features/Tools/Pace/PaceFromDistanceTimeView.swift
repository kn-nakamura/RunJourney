import SwiftUI

/// Pace/Speed モード: 距離 + タイム → ペース + 速度 + 400m トラック + Custom 距離ペース
struct PaceFromDistanceTimeView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    @AppStorage("customDistanceKm") private var customDistanceKm: Double = 10.0

    @State private var distanceKm: Double = 42.195
    @State private var distanceText: String = ""
    @State private var timeSec: Int = 3 * 3600

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    /// Double 秒/km — 端数を保持して結果カードで hundredths 表示する
    private var paceSecPerKm: Double {
        guard distanceKm > 0, timeSec > 0 else { return 0 }
        return Double(timeSec) / distanceKm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Distance")
                DistancePresetChips(distanceKm: $distanceKm)
                distanceField
            }

            PaceTimeSpinner(
                title: "Time",
                mode: .goalTime,
                seconds: $timeSec,
                derivedGoalTimeSeconds: nil
            )

            ToolsResultCard(title: "Pace / Speed") {
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(
                        value: PaceUtils.formatPaceTrackHundredths(PaceUtils.paceSecondsPerUnitPrecise(secPerKm: paceSecPerKm, in: unit)),
                        unit: unit.perLabel,
                        detail: "(\(String(format: "%.2f", PaceUtils.speed(secPerKm: Int(paceSecPerKm.rounded()), in: unit))) \(unit.speedLabel))"
                    )
                    metricRow(
                        value: PaceUtils.formatPaceTrackHundredths(paceSecPerKm * 0.4),
                        unit: "/ 400m Track",
                        detail: nil
                    )
                    metricRow(
                        value: PaceUtils.formatTimeSimple(Int((paceSecPerKm * customDistanceKm).rounded())),
                        unit: "/ \(PaceUtils.formatDistance(km: customDistanceKm, in: unit))",
                        detail: nil
                    )
                    Text("Set a frequently-used distance in Settings → Custom Distance.")
                        .appText(.bodyXs)
                        .foregroundStyle(.tertiary)
                }
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

    private func metricRow(value: String, unit: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .appText(.codeLgBold)
                .foregroundStyle(Color.accentPrimary)
            Text(unit)
                .appText(.codeSm)
                .foregroundStyle(.secondary)
            Spacer()
            if let detail {
                Text(detail)
                    .appText(.codeSm)
                    .foregroundStyle(.secondary)
            }
        }
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
