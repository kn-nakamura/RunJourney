import SwiftUI

/// 応援地点 km、レース距離 km、ゴール予想タイム、(任意) スタート時刻 から
/// 応援地点での通過予想時刻と ±5% バンドを計算する。
struct CheerFromGoalTimeView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var cheerKm: Double = 21.0975
    @State private var raceKm: Double = 42.195
    @State private var cheerText: String = ""
    @State private var raceText: String = ""
    @State private var goalTimeSec: Int = 4 * 3600

    @State private var startTime: Date = .now
    @State private var startEnabled: Bool = false

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var elapsedSec: Int? {
        guard raceKm > 0, goalTimeSec > 0 else { return nil }
        let frac = cheerKm / raceKm
        return Int((Double(goalTimeSec) * frac).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Cheer Point")
                kmField($cheerText, commit: commitCheer, label: unit.label)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Race Distance")
                DistancePresetChips(distanceKm: $raceKm)
                kmField($raceText, commit: commitRace, label: unit.label)
            }

            PaceTimeSpinner(
                title: "Goal Time",
                mode: .goalTime,
                seconds: $goalTimeSec,
                derivedGoalTimeSeconds: nil
            )

            startTimeRow

            ToolsResultCard(title: "Predicted Pass Time") {
                resultRows
            }
        }
        .onAppear {
            cheerText = formatKmText(cheerKm)
            raceText = formatKmText(raceKm)
        }
        .onChange(of: cheerKm) { _, _ in cheerText = formatKmText(cheerKm) }
        .onChange(of: raceKm) { _, _ in raceText = formatKmText(raceKm) }
        .onChange(of: distanceUnitRaw) { _, _ in
            cheerText = formatKmText(cheerKm)
            raceText = formatKmText(raceKm)
        }
    }

    private var startTimeRow: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $startEnabled) {
                Text("Start Time")
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .tint(Color.accentPrimary)

            if startEnabled {
#if os(iOS)
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
#else
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
#endif
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var resultRows: some View {
        if let elapsed = elapsedSec {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(PaceUtils.formatHMSPaceStyle(elapsed))
                        .appText(.codeXl)
                        .foregroundStyle(Color.accentPrimary)
                    Spacer()
                    if startEnabled {
                        Text(absoluteTime(offset: elapsed))
                            .appText(.codeMd)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider().background(Color.borderColor)
                Text("(-5% ~ +5%)")
                    .appText(.eyebrow)
                    .foregroundStyle(.tertiary)
                let lower = Int((Double(elapsed) * 0.95).rounded())
                let upper = Int((Double(elapsed) * 1.05).rounded())
                HStack(alignment: .firstTextBaseline) {
                    Text(PaceUtils.formatHMSPaceStyle(lower))
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                    Text("~")
                        .appText(.codeMd)
                        .foregroundStyle(.tertiary)
                    Text(PaceUtils.formatHMSPaceStyle(upper))
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if startEnabled {
                        Text("\(absoluteTime(offset: lower)) ~ \(absoluteTime(offset: upper))")
                            .appText(.codeXs)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } else {
            Text("Enter race distance and goal time to predict pass time.")
                .appText(.bodyXs)
                .foregroundStyle(.tertiary)
        }
    }

    private func absoluteTime(offset: Int) -> String {
        let date = startTime.addingTimeInterval(Double(offset))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func kmField(_ text: Binding<String>, commit: @escaping () -> Void, label: String) -> some View {
        HStack {
#if os(iOS)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .onSubmit(commit)
#else
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
                .onSubmit(commit)
#endif
            Text(label)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatKmText(_ km: Double) -> String {
        PaceUtils.formatDistanceValue(km: km, in: unit)
    }

    private func commitCheer() {
        let s = cheerText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(s), parsed >= 0 else { cheerText = formatKmText(cheerKm); return }
        cheerKm = parsed.toKm(from: unit)
    }

    private func commitRace() {
        let s = raceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(s), parsed > 0 else { raceText = formatKmText(raceKm); return }
        raceKm = parsed.toKm(from: unit)
    }
}
