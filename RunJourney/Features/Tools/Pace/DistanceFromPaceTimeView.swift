import SwiftUI

/// Distance モード: ペース + 時間 → 距離
struct DistanceFromPaceTimeView: View {
    @AppStorage("distanceUnit") private var distanceUnitRaw: String = DistanceUnit.km.rawValue

    @State private var pacePerKm: Int = 5 * 60
    @State private var paceMin: Int = 5
    @State private var paceSec: Int = 0
    @State private var timeSec: Int = 3600

    private var unit: DistanceUnit { DistanceUnit.resolve(distanceUnitRaw) }

    private var distanceKm: Double {
        guard pacePerKm > 0 else { return 0 }
        return Double(timeSec) / Double(pacePerKm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Pace")
                paceField
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Time")
                HMSField(totalSeconds: $timeSec)
            }

            ToolsResultCard(title: "Distance") {
                Text(distanceKm > 0 ? PaceUtils.formatDistance(km: distanceKm, in: unit) : "—")
                    .appText(.codeXl)
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .onAppear { syncPaceFromUnit() }
        .onChange(of: distanceUnitRaw) { _, _ in syncPaceFromUnit() }
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
            ? Binding(get: { paceMin }, set: { paceMin = Swift.max(0, $0) })
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

    private func pushPace() {
        let displayedSec = paceMin * 60 + paceSec
        if unit == .km {
            pacePerKm = displayedSec
        } else {
            pacePerKm = Int((Double(displayedSec) / kmPerMile).rounded())
        }
    }

    private func syncPaceFromUnit() {
        let displayed = PaceUtils.paceSecondsPerUnit(secPerKm: pacePerKm, in: unit)
        paceMin = displayed / 60
        paceSec = displayed % 60
    }
}
