import SwiftUI

/// TOOLS · Calculator モード:
/// 「時間と距離の電卓」。Time(秒) と Distance(km) を ± × ÷ で組み合わせて以下を一発計算する。
///
/// - time ± time → 合計/差 (秒)
/// - time × N    → タイム × 倍率
/// - time ÷ N    → タイム ÷ 倍率
/// - time ÷ km   → ペース (秒/km)
/// - time × km   → トータルタイム (ペース × km)
struct TimeCalculatorView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue
    @AppStorage("customDistanceKm") private var customDistanceKm: Double = 10.0

    @State private var distanceKm: Double = 42.195
    @State private var distanceText: String = ""
    @State private var timeSec: Int = 0

    @State private var op: Operation = .div
    @State private var operandText: String = ""
    @State private var operandTimeSec: Int = 0

    @State private var resultText: String? = nil

    enum Operation: String, CaseIterable, Identifiable {
        case add = "+"
        case sub = "−"
        case mul = "×"
        case div = "÷"
        case divKm = "÷ Distance"
        case mulKm = "× Distance"
        var id: String { rawValue }
    }

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }
    private var operandIsTime: Bool { op == .add || op == .sub }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Distance row
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Distance")
                DistancePresetChips(distanceKm: $distanceKm)
                distanceField
            }

            // Time row — PaceTimeSpinner で chevron 入力
            PaceTimeSpinner(
                title: "Time",
                mode: .goalTime,
                seconds: $timeSec,
                derivedGoalTimeSeconds: nil
            )

            // Operation
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Operation")
                Picker("Operation", selection: $op) {
                    ForEach(Operation.allCases) { o in
                        Text(o.rawValue).tag(o)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Operand
            if operandIsTime {
                PaceTimeSpinner(
                    title: "Operand",
                    mode: .goalTime,
                    seconds: $operandTimeSec,
                    derivedGoalTimeSeconds: nil
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Operand")
                    operandField
                }
            }

            // Actions
            HStack(spacing: 8) {
                Button("AC") { reset() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("=") { compute() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color.accentPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Result
            ToolsResultCard(title: "Result") {
                Text(resultText ?? "—")
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .onAppear { distanceText = formatDistanceText() }
        .onChange(of: distanceKm) { _, _ in distanceText = formatDistanceText() }
        .onChange(of: distanceUnitRaw) { _, _ in distanceText = formatDistanceText() }
    }

    // MARK: - Distance / Operand TextField

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

    private var operandField: some View {
        HStack {
#if os(iOS)
            TextField("0", text: $operandText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
#else
            TextField("0", text: $operandText)
                .multilineTextAlignment(.trailing)
                .font(.appFont(.codeBaseBold))
#endif
            if op == .divKm || op == .mulKm {
                Text(unit.label)
                    .appText(.bodySm)
                    .foregroundStyle(.secondary)
            }
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

    // MARK: - Compute

    private func compute() {
        commitDistance()
        let operand = parseOperand()
        switch op {
        case .add:
            let total = timeSec + operandTimeSec
            resultText = PaceUtils.formatTimeSimple(total)
        case .sub:
            let total = max(0, timeSec - operandTimeSec)
            resultText = PaceUtils.formatTimeSimple(total)
        case .mul:
            guard operand > 0 else { resultText = "—"; return }
            let total = Int((Double(timeSec) * operand).rounded())
            resultText = PaceUtils.formatTimeSimple(total)
        case .div:
            guard operand > 0 else { resultText = "—"; return }
            let total = Int((Double(timeSec) / operand).rounded())
            resultText = PaceUtils.formatTimeSimple(total)
        case .divKm:
            // time ÷ distance → pace (端数を保持して hundredths 表示)
            guard distanceKm > 0, timeSec > 0 else { resultText = "—"; return }
            let secPerKm = Double(timeSec) / distanceKm
            resultText = PaceUtils.formatPaceHundredths(secPerKm: secPerKm, in: unit)
        case .mulKm:
            // time × distance → trip total (treat time as pace per km)
            guard distanceKm > 0 else { resultText = "—"; return }
            let total = PaceUtils.paceToGoalTime(pacePerKm: timeSec, distanceKm: distanceKm)
            resultText = PaceUtils.formatTimeSimple(total)
        }
    }

    private func parseOperand() -> Double {
        let s = operandText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(s) ?? 0
    }

    private func reset() {
        timeSec = 0
        operandTimeSec = 0
        operandText = ""
        resultText = nil
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            TimeCalculatorView()
                .padding()
        }
    }
}
