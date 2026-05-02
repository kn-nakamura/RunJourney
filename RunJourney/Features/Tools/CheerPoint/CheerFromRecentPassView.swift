import SwiftUI

/// 直近の通過ポイント (km / 通過所要時間) から、応援地点での通過予想時刻を線形外挿で推定。
/// 現場で「最後の通過から今のペース」を更新したいときに使う。
struct CheerFromRecentPassView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var cheerKm: Double = 30
    @State private var recentKm: Double = 10
    @State private var cheerText: String = ""
    @State private var recentText: String = ""
    @State private var recentTimeSec: Int = 50 * 60

    @State private var startTime: Date = .now
    @State private var startEnabled: Bool = false

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var elapsedSec: Int? {
        guard recentKm > 0, recentTimeSec > 0 else { return nil }
        let pacePerKm = Double(recentTimeSec) / recentKm
        let predicted = Double(recentTimeSec) + pacePerKm * (cheerKm - recentKm)
        return Int(predicted.rounded())
    }

    private var alreadyPassed: Bool {
        cheerKm < recentKm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Cheer Point")
                kmField($cheerText, commit: commitCheer, label: unit.label)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Recent Pass Point")
                kmField($recentText, commit: commitRecent, label: unit.label)
            }

            PaceTimeSpinner(
                title: "Recent Pass Time",
                mode: .goalTime,
                seconds: $recentTimeSec,
                derivedGoalTimeSeconds: nil
            )

            startTimeRow

            ToolsResultCard(title: "Predicted Pass Time") {
                resultRows
            }
        }
        .onAppear {
            cheerText = formatKmText(cheerKm)
            recentText = formatKmText(recentKm)
        }
        .onChange(of: cheerKm) { _, _ in cheerText = formatKmText(cheerKm) }
        .onChange(of: recentKm) { _, _ in recentText = formatKmText(recentKm) }
        .onChange(of: distanceUnitRaw) { _, _ in
            cheerText = formatKmText(cheerKm)
            recentText = formatKmText(recentKm)
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
                if alreadyPassed {
                    Text("Already passed (back-extrapolated)")
                        .appText(.eyebrow)
                        .foregroundStyle(Color.cat10K)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(PaceUtils.formatHMSPaceStyle(max(0, elapsed)))
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
                    Text(PaceUtils.formatHMSPaceStyle(max(0, lower)))
                        .appText(.codeMd)
                        .foregroundStyle(Color.textPrimary)
                    Text("~")
                        .appText(.codeMd)
                        .foregroundStyle(.tertiary)
                    Text(PaceUtils.formatHMSPaceStyle(max(0, upper)))
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
            Text("Enter recent pass point and time to predict the cheer point pass time.")
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

    private func commitRecent() {
        let s = recentText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(s), parsed >= 0 else { recentText = formatKmText(recentKm); return }
        recentKm = parsed.toKm(from: unit)
    }
}
