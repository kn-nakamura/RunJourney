import SwiftUI

/// Time モード: ペース + 距離 → 合計タイム
struct TimeFromPaceDistanceView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var distanceKm: Double = 42.195
    @State private var distanceText: String = ""
    /// ペースは内部 sec/km で保持する。表示は単位に応じて変換。
    @State private var pacePerKm: Int = 5 * 60
    @State private var paceMin: Int = 5
    @State private var paceSec: Int = 0

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var totalSec: Int {
        guard distanceKm > 0, pacePerKm > 0 else { return 0 }
        return Int((Double(pacePerKm) * distanceKm).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Pace")
                paceField
            }

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
        .onAppear {
            distanceText = formatDistanceText()
            syncPaceFromUnit()
        }
        .onChange(of: distanceKm) { _, _ in distanceText = formatDistanceText() }
        .onChange(of: distanceUnitRaw) { _, _ in
            distanceText = formatDistanceText()
            syncPaceFromUnit()
        }
        .onChange(of: paceMin) { _, _ in pushPace() }
        .onChange(of: paceSec) { _, _ in pushPace() }
    }

    private var paceField: some View {
        HStack(spacing: 6) {
            paceCell(min: true)
            Text("'")
                .appText(.codeMd)
                .foregroundStyle(.secondary)
            paceCell(min: false)
            Text("\"")
                .appText(.codeMd)
                .foregroundStyle(.secondary)
            Spacer()
            Text(unit.perLabel)
                .appText(.bodySm)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func paceCell(min: Bool) -> some View {
        let binding = min
            ? Binding(get: { paceMin }, set: { paceMin = max(0, $0) })
            : Binding(get: { paceSec }, set: { paceSec = Swift.max(0, Swift.min(59, $0)) })
        return TextField(min ? "0" : "00",
                         value: binding,
                         format: .number)
#if os(iOS)
            .keyboardType(.numberPad)
#endif
            .multilineTextAlignment(.center)
            .font(.appFont(.codeLgBold))
            .frame(width: 48)
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
        let v = distanceKm.displayed(in: unit)
        return abs(v) >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v)
    }

    private func commitDistance() {
        let s = distanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(s), parsed > 0 else {
            distanceText = formatDistanceText()
            return
        }
        distanceKm = parsed.toKm(from: unit)
    }

    /// ユーザーが入力したペース (表示単位) → 内部 sec/km に変換して `pacePerKm` を更新
    private func pushPace() {
        let displayedSec = paceMin * 60 + paceSec
        if unit == .km {
            pacePerKm = displayedSec
        } else {
            // displayedSec is sec/mi → sec/km = sec/mi / kmPerMile
            pacePerKm = Int((Double(displayedSec) / kmPerMile).rounded())
        }
    }

    /// 単位切替時、内部 pacePerKm を表示単位に合わせて再表示
    private func syncPaceFromUnit() {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit)
        paceMin = displayed / 60
        paceSec = displayed % 60
    }
}
